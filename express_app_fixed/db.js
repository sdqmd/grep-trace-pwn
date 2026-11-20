// Database helpers. FIXED: every query is parameterised.
// Compare: diff -u express_app/db.js express_app_fixed/db.js
const Database = require("better-sqlite3");
const path = require("path");

const db = new Database(path.join(__dirname, "app.db"));

function initDb() {
  db.exec(`
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
  `);
}

function query(sql, params = []) {
  return db.prepare(sql).all(...params);
}

function getUser(uid) {
  // FIXED: "?" placeholder. uid is bound as data.
  const sql = "SELECT id, username, email FROM users WHERE id = ?";
  return { sql, rows: query(sql, [uid]) };
}

function getOrder(oid) {
  const sql = "SELECT id, item, qty FROM orders WHERE id = ?";
  return { sql, rows: query(sql, [oid]) };
}

module.exports = { initDb, getUser, getOrder };
