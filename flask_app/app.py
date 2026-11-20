"""
grep-trace-pwn: intentionally vulnerable Flask app.
5 flows + 1 decoy. Find them. Trace them. Pwn them.
"""
from flask import Flask, request, render_template_string, jsonify
import requests

from db import init_db, get_user, get_order
from utils import run_cmd, read_doc

app = Flask(__name__)
init_db()

ROUTES = {
    "/user?id=1": "look up a user",
    "/ping?host=127.0.0.1": "ping a host",
    "/docs?name=readme.txt": "read a doc",
    "/hello?name=world": "greet",
    "/fetch?url=http://example.com": "fetch a URL server-side",
    "/order?id=1": "look up an order",
}


@app.route("/")
def index():
    links = "".join(f'<li><a href="{p}">{p}</a> &mdash; {d}</li>' for p, d in ROUTES.items())
    return f"<h1>grep-trace-pwn / Flask</h1><ul>{links}</ul>"


@app.route("/user")
def user():
    uid = request.args.get("id", "1")
    return jsonify(get_user(uid))


@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    return "<pre>" + run_cmd("ping -c 1 " + host) + "</pre>"


@app.route("/docs")
def docs():
    name = request.args.get("name", "readme.txt")
    return "<pre>" + read_doc(name) + "</pre>"


@app.route("/hello")
def hello():
    name = request.args.get("name", "world")
    return render_template_string("<h1>Hello " + name + "</h1>")


@app.route("/fetch")
def fetch():
    url = request.args.get("url", "http://example.com")
    r = requests.get(url, timeout=3)
    return "<pre>" + r.text[:2000] + "</pre>"


@app.route("/order")
def order():
    oid = request.args.get("id", "1")
    return jsonify(get_order(int(oid)))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
