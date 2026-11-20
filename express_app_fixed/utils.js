// Misc helpers. FIXED: no shell, and a real path check.
// Compare: diff -u express_app/utils.js express_app_fixed/utils.js
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const DOCS_DIR = fs.realpathSync(path.join(__dirname, "docs"));

function runCmd(file, args) {
  // FIXED: execFile with an argument array. No shell is involved.
  try {
    return execFileSync(file, args, { timeout: 5000 }).toString();
  } catch (e) {
    return (e.stdout || "").toString() + (e.stderr || "").toString();
  }
}

function safePath(name) {
  // FIXED: resolve, then prove it is still inside DOCS_DIR.
  const p = path.resolve(DOCS_DIR, name);
  if (!p.startsWith(DOCS_DIR + path.sep)) throw new Error("path escapes docs dir");
  return p;
}

function readDoc(name) {
  return fs.readFileSync(safePath(name), "utf8");
}

module.exports = { runCmd, readDoc };
