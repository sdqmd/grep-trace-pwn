#!/bin/sh
# Runs both apps. Flask on :5000, Express on :3000.
cd /app/flask_app && python3 app.py &
cd /app/express_app && node server.js &
echo "grep-trace-pwn up: Flask http://localhost:5000  Express http://localhost:3000"
wait
