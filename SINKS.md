# SINKS.md: the cheatsheet

A function is a **sink** when it *interprets* its argument: as code, a shell command, a SQL
query, a file path, HTML, a URL, or a memory length. It's only a bug when that argument is
attacker-controlled (comes from a **source**) and nothing in between cleans it (**sanitizer**).

Memorise this page. It's half the job.

## Sources (where attacker data enters)

- `request.args`, `request.form`, `request.json`
- `request.headers`, `request.cookies`
- `request.files`
- `request.path`, `request.url`
- `sys.argv`, `os.environ`
- rows read back from DB (stored)
- responses from third-party APIs

## Sinks (where attacker data becomes dangerous)

| Bug class | Python |
|---|---|
| Code injection | `eval`, `exec`, `compile` |
| Command injection | `os.system`, `os.popen`, `subprocess.*(shell=True)` |
| SQL injection | `cursor.execute(f"…")`, `.raw()`, `text()` |
| Path traversal | `open`, `os.path.join` (no check), `send_file` |
| Deserialization | `pickle.loads`, `yaml.load` (no SafeLoader), `marshal` |
| Template injection | `render_template_string`, `Template(…).render` |
| XSS | `Markup(…)`, `\|safe` in templates |
| SSRF | `requests.get(url)`, `urllib.request.urlopen` |
| Open redirect | `redirect(url)` |
| XXE | `lxml.etree.parse`, `xml.dom.minidom` |
| Regex DoS | `re.compile(user_pattern)` |

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

```bash
grep -rnE "eval\(|exec\(|os\.system|os\.popen|subprocess|\.execute\(|\.raw\(|open\(|pickle\.loads|yaml\.load|render_template_string|requests\.(get|post)|urlopen|redirect\(" --include=*.py .
```

Wrappers (devs rename sinks):

```bash
grep -rnE "def (run|exec|shell|cmd|query|sql|load|render|fetch|read)_?\w*\(" --include=*.py .
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
