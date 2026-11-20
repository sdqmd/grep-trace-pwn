"""
grep-trace-pwn: the SAME Flask app with every sink fixed at the sink.
Same routes, same payloads, different outcome.
Compare: diff -u flask_app/app.py flask_app_fixed/app.py
"""
from urllib.parse import urlparse
from flask import Flask, request, render_template_string, jsonify, abort
import requests

from db import init_db, get_user, get_order
from utils import run_cmd, read_doc

app = Flask(__name__)
init_db()

ALLOWED_FETCH_HOSTS = {"example.com", "www.example.com"}

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
    return f"<h1>grep-trace-pwn / Flask (FIXED)</h1><ul>{links}</ul>"


@app.route("/user")
def user():
    uid = request.args.get("id", "1")
    return jsonify(get_user(uid))


@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # FIXED: argument list, not a string. The shell never sees it.
    return "<pre>" + run_cmd(["ping", "-c", "1", host]) + "</pre>"


@app.route("/docs")
def docs():
    name = request.args.get("name", "readme.txt")
    try:
        return "<pre>" + read_doc(name) + "</pre>"
    except (ValueError, FileNotFoundError):
        abort(400)


@app.route("/hello")
def hello():
    name = request.args.get("name", "world")
    # FIXED: user data goes in as context. The template is a constant.
    return render_template_string("<h1>Hello {{ name }}</h1>", name=name)


def safe_url(url):
    # FIXED: scheme and host allowlist before the request leaves.
    u = urlparse(url)
    if u.scheme not in ("http", "https") or u.hostname not in ALLOWED_FETCH_HOSTS:
        raise ValueError("host not allowed")
    return url


@app.route("/fetch")
def fetch():
    url = request.args.get("url", "http://example.com")
    try:
        r = requests.get(safe_url(url), timeout=3)
    except ValueError:
        abort(400)
    return "<pre>" + r.text[:2000] + "</pre>"


@app.route("/order")
def order():
    oid = request.args.get("id", "1")
    return jsonify(get_order(oid))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=False)
