// grep-trace-pwn: the SAME Express app with every sink fixed at the sink.
// Compare: diff -u express_app/server.js express_app_fixed/server.js
const express = require("express");
const ejs = require("ejs");
const { initDb, getUser, getOrder } = require("./db");
const { runCmd, readDoc } = require("./utils");

const app = express();
initDb();

const ALLOWED_FETCH_HOSTS = new Set(["example.com", "www.example.com"]);

const ROUTES = {
  "/user?id=1": "look up a user",
  "/ping?host=127.0.0.1": "ping a host",
  "/docs?name=readme.txt": "read a doc",
  "/hello?name=world": "greet",
  "/fetch?url=http://example.com": "fetch a URL server-side",
  "/order?id=1": "look up an order",
};

app.get("/", (req, res) => {
  const links = Object.entries(ROUTES)
    .map(([p, d]) => `<li><a href="${p}">${p}</a> &mdash; ${d}</li>`)
    .join("");
  res.send(`<h1>grep-trace-pwn / Express (FIXED)</h1><ul>${links}</ul>`);
});

app.get("/user", (req, res) => {
  const uid = req.query.id || "1";
  res.json(getUser(uid));
});

app.get("/ping", (req, res) => {
  const host = req.query.host || "127.0.0.1";
  // FIXED: argument array, the shell never sees it.
  res.send("<pre>" + runCmd("ping", ["-c", "1", host]) + "</pre>");
});

app.get("/docs", (req, res) => {
  const name = req.query.name || "readme.txt";
  try {
    res.send("<pre>" + readDoc(name) + "</pre>");
  } catch (e) {
    res.status(400).send("bad path");
  }
});

app.get("/hello", (req, res) => {
  const name = req.query.name || "world";
  // FIXED: user data goes in as context. The template is a constant.
  res.send(ejs.render("<h1>Hello <%= name %></h1>", { name }));
});

function safeUrl(url) {
  // FIXED: scheme and host allowlist before the request leaves.
  const u = new URL(url);
  if (!["http:", "https:"].includes(u.protocol) || !ALLOWED_FETCH_HOSTS.has(u.hostname)) {
    throw new Error("host not allowed");
  }
  return url;
}

app.get("/fetch", async (req, res) => {
  const url = req.query.url || "http://example.com";
  try {
    const r = await fetch(safeUrl(url), { signal: AbortSignal.timeout(3000) });
    const body = await r.text();
    res.send("<pre>" + body.slice(0, 2000) + "</pre>");
  } catch (e) {
    res.status(400).send("<pre>" + String(e) + "</pre>");
  }
});

app.get("/order", (req, res) => {
  const oid = req.query.id || "1";
  res.json(getOrder(oid));
});

app.use((err, req, res, next) => {
  res.status(500).send("<pre>" + String(err) + "</pre>");
});

app.listen(3002, "0.0.0.0", () => console.log("express (fixed) on :3002"));
