"""Database helpers. FIXED: every query is parameterised, so the sink no longer
interprets its argument. Compare: diff -u flask_app/db.py flask_app_fixed/db.py"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "app.db")


def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.executescript(
        """
        DROP TABLE IF EXISTS users;
        DROP TABLE IF EXISTS orders;
        DROP TABLE IF EXISTS secrets;
        CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, email TEXT);
        CREATE TABLE orders (id INTEGER PRIMARY KEY, item TEXT, qty INTEGER);
        CREATE TABLE secrets (id INTEGER PRIMARY KEY, name TEXT, value TEXT);
        INSERT INTO users VALUES (1, 'alice', 'alice@example.com');
        INSERT INTO users VALUES (2, 'bob', 'bob@example.com');
        INSERT INTO orders VALUES (1, 'keyboard', 2);
        INSERT INTO orders VALUES (2, 'mouse', 1);
        INSERT INTO secrets VALUES (1, 'admin_password', 'FLAG{sqli_union_select_works}');
        INSERT INTO secrets VALUES (2, 'api_key', 'sk-live-dont-leak-me');
        """
    )
    conn.commit()
    conn.close()


def _query(sql, params=()):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(sql, params)
    rows = cur.fetchall()
    conn.close()
    return rows


def get_user(uid):
    # FIXED: "?" placeholder. uid is data, never part of the query text.
    sql = "SELECT id, username, email FROM users WHERE id = ?"
    return {"sql": sql, "rows": _query(sql, (uid,))}


def get_order(oid):
    sql = "SELECT id, item, qty FROM orders WHERE id = ?"
    return {"sql": sql, "rows": _query(sql, (oid,))}
