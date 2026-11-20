// Misc helpers. Devs love wrapping dangerous things in friendly names.
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const DOCS_DIR = path.join(__dirname, "docs");

function runCmd(cmd) {
  // Flow 2 sink, hidden behind a wrapper. grep for child_process finds this.
  // grep for runCmd finds who calls it.
  try {
    return execSync(cmd, { timeout: 5000 }).toString();
  } catch (e) {
    return (e.stdout || "").toString() + (e.stderr || "").toString();
  }
}

function readDoc(name) {
  // Flow 3 sink. path.join does NOT sanitize "../".
  const p = path.join(DOCS_DIR, name);
  return fs.readFileSync(p, "utf8");
}

module.exports = { runCmd, readDoc };
