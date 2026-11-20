# SINKS.md: the cheatsheet

A function is a **sink** when it *interprets* its argument: as code, a shell command, a SQL
query, a file path, HTML, a URL, or a memory length. It's only a bug when that argument is
attacker-controlled (comes from a **source**) and nothing in between cleans it (**sanitizer**).

Memorise this page. It's half the job.

## Sources (where attacker data enters)

| Python (Flask) | JS (Express) |
|---|---|
| `request.args`, `request.form`, `request.json` | `req.query`, `req.body`, `req.params` |
| `request.headers`, `request.cookies` | `req.headers`, `req.cookies` |
| `request.files` | `req.files` (multer) |
| `request.path`, `request.url` | `req.path`, `req.originalUrl` |
| `sys.argv`, `os.environ` | `process.argv`, `process.env` |
| rows read back from DB (stored) | rows read back from DB (stored) |
| responses from third-party APIs | responses from third-party APIs |

## Sinks (where attacker data becomes dangerous)

| Bug class | Python | JS / Node |
|---|---|---|
| Code injection | `eval`, `exec`, `compile` | `eval`, `new Function`, `vm.runInContext` |
| Command injection | `os.system`, `os.popen`, `subprocess.*(shell=True)` | `child_process.exec`, `execSync`, `spawn(…, {shell:true})` |
| SQL injection | `cursor.execute(f"…")`, `.raw()`, `text()` | `db.query("…"+x)`, `db.prepare("…"+x)`, `sequelize.query` |
| Path traversal | `open`, `os.path.join` (no check), `send_file` | `fs.readFile*`, `fs.writeFile*`, `path.join` (no check), `res.sendFile` |
| Deserialization | `pickle.loads`, `yaml.load` (no SafeLoader), `marshal` | `node-serialize`, `JSON.parse` → prototype pollution |
| Template injection | `render_template_string`, `Template(…).render` | `ejs.render(str)`, `pug.compile(str)`, `_.template` |
| XSS | `Markup(…)`, `\|safe` in templates | `innerHTML`, `res.send(html+x)`, `dangerouslySetInnerHTML` |
| SSRF | `requests.get(url)`, `urllib.request.urlopen` | `fetch(url)`, `axios.get(url)`, `http.get` |
| Open redirect | `redirect(url)` | `res.redirect(url)` |
| XXE | `lxml.etree.parse`, `xml.dom.minidom` | `libxmljs` (noent) |
| Regex DoS | `re.compile(user_pattern)` | `new RegExp(user_pattern)` |

## Sanitizers (what breaks the chain, and what it protects against)

| Sanitizer | Stops | Does NOT stop |
|---|---|---|
| `int(x)` / `parseInt(x)` | SQLi, cmdi, traversal (if used) | anything if value isn't actually used |
| Parameterised query (`?`, `%s`, `$1`) | SQLi | cmdi, traversal |
| `shlex.quote` / `shell: false` + array args | cmdi | SQLi |
| `os.path.realpath` + prefix check | traversal | — |
| `html.escape` / `escape()` | XSS | SQLi, cmdi, SSTI |
| URL allowlist (scheme + host) | SSRF, open redirect | — |
| `yaml.safe_load`, `json.loads` | deser | — |

**The sanitizer must match the sink.** HTML-escaping before a SQL query does nothing.

## Grep one-liners

Python:

```bash
grep -rnE "eval\(|exec\(|os\.system|os\.popen|subprocess|\.execute\(|\.raw\(|open\(|pickle\.loads|yaml\.load|render_template_string|requests\.(get|post)|urlopen|redirect\(" --include=*.py .
```

JS:

```bash
grep -rnE "eval\(|new Function|child_process|exec(Sync)?\(|\.query\(|\.prepare\(|readFile|writeFile|sendFile|innerHTML|res\.send\(|fetch\(|axios|res\.redirect|new RegExp" --include=*.js .
```

Wrappers (devs rename sinks):

```bash
grep -rnE "def (run|exec|shell|cmd|query|sql|load|render|fetch|read)_?\w*\(" --include=*.py .
grep -rnE "function (run|exec|shell|cmd|query|sql|load|render|fetch|read)\w*\(" --include=*.js .
```

## Binary / C equivalents (same idea, worse visibility)

| Class | Sinks |
|---|---|
| Buffer overflow | `strcpy`, `strcat`, `sprintf`, `gets`, `memcpy(dst, src, user_len)` |
| Format string | `printf(user)`, `syslog(user)` |
| Command injection | `system`, `popen`, `execve` with shell |
| Integer issues | `malloc(user_len)`, arithmetic before `memcpy` |
| Use-after-free | `free` then any use |

Grep = `strings`, imports table, xrefs in Ghidra/IDA. Trace = decompiler. Pwn = craft by hand or fuzz (AFL++, libFuzzer, ASan).
