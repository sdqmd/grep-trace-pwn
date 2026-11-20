#!/bin/sh
# Runs all four services.
#   vulnerable: Flask :5000   Express :3000
#   fixed:      Flask :5002   Express :3002
cd /app/flask_app && python3 app.py &
cd /app/express_app && node server.js &
cd /app/flask_app_fixed && python3 app.py &
cd /app/express_app_fixed && node server.js &
echo "grep-trace-pwn up"
echo "  vulnerable  Flask http://localhost:5000   Express http://localhost:3000"
echo "  fixed       Flask http://localhost:5002   Express http://localhost:3002"
echo "stop with: docker stop gtp"
wait
