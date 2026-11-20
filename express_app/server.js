// grep-trace-pwn: intentionally vulnerable Express app.
// 5 flows + 1 decoy. Find them. Trace them. Pwn them.
const express = require("express");
const { initDb, getUser, getOrder } = require("./db");
const { runCmd, readDoc } = require("./utils");

const app = express();
initDb();

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
  res.send(`<h1>grep-trace-pwn / Express</h1><ul>${links}</ul>`);
});

app.get("/user", (req, res) => {
  const uid = req.query.id || "1";
  res.json(getUser(uid));
});

app.get("/ping", (req, res) => {
  const host = req.query.host || "127.0.0.1";
  res.send("<pre>" + runCmd("ping -c 1 " + host) + "</pre>");
});

app.get("/docs", (req, res) => {
  const name = req.query.name || "readme.txt";
  res.send("<pre>" + readDoc(name) + "</pre>");
});

app.get("/hello", (req, res) => {
  const name = req.query.name || "world";
  res.send("<h1>Hello " + name + "</h1>");
});

app.get("/fetch", async (req, res) => {
  const url = req.query.url || "http://example.com";
  try {
    const r = await fetch(url, { signal: AbortSignal.timeout(3000) });
    const body = await r.text();
    res.send("<pre>" + body.slice(0, 2000) + "</pre>");
  } catch (e) {
    res.status(500).send("<pre>" + String(e) + "</pre>");
  }
});

app.get("/order", (req, res) => {
  const oid = req.query.id || "1";
  res.json(getOrder(parseInt(oid, 10)));
});

app.use((err, req, res, next) => {
  res.status(500).send("<pre>" + String(err) + "</pre>");
});

app.listen(3000, "0.0.0.0", () => console.log("express on :3000"));
