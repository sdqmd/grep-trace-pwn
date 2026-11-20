# grep, trace, pwn

Companion repo for the talk **"grep, trace, pwn"**: an intro to source-to-sink code auditing.

**Read this as a site:** https://sdqmd.github.io/grep-trace-pwn/

Hacking isn't magic. It's three verbs:

1. **grep** for dangerous functions (sinks)
2. **trace** their arguments back to attacker input (sources)
3. **pwn** by building a payload that survives the path

This repo gives you a tiny, intentionally vulnerable Flask app with 5 planted bugs and one
decoy, so you can practise all three steps.

![grep, trace, pwn in 20 seconds](demo.gif)

## Run it

```bash
docker run --rm --name gtp -p 127.0.0.1:5000:5000 ghcr.io/sdqmd/grep-trace-pwn
```

Or build locally:

```bash
git clone https://github.com/sdqmd/grep-trace-pwn && cd grep-trace-pwn
docker build -t grep-trace-pwn . && docker run --rm --name gtp -p 127.0.0.1:5000:5000 grep-trace-pwn
```

Open http://localhost:5000. Six routes, each takes a query parameter.

> macOS: if you get a 403 on port 5000, AirPlay Receiver has it. Turn it off in
> System Settings → General → AirDrop & Handoff, or map another port:
> `-p 127.0.0.1:5001:5000` and read 5001 wherever this guide says 5000.

## Stop it

```bash
docker stop gtp
```

`--rm` removes the container on stop. To reclaim the disk space too:

```bash
docker rmi ghcr.io/sdqmd/grep-trace-pwn
```

Forgot the name? `docker ps` lists what's running, `docker stop <id>` stops it.

Then open **[GUIDE.md](GUIDE.md)** and work through it.

## What's inside

| File | Purpose |
|---|---|
| `GUIDE.md` | step-by-step: grep → trace → pwn → fix → automate |
| `SINKS.md` | the cheatsheet. dangerous functions for Python + JS. memorise it |
| `flask_app/` | the target, ~100 lines |
| `semgrep/` | taint rules that find (some of) the flows automatically |
| `check.sh` | fires every payload, PASS/FAIL per flow. Fix a sink and watch its row flip |
| `demo.sh` | the live-demo commands, in order |
| `demo.tape` | [VHS](https://github.com/charmbracelet/vhs) script that renders `demo.gif` |

## The flows

Don't read this until you've tried grepping yourself.

<details>
<summary>spoilers</summary>

| # | Route | Class | Sink |
|---|---|---|---|
| 1 | `/user?id=` | SQL injection | `cursor.execute` |
| 2 | `/ping?host=` | Command injection | `subprocess.run(shell=True)` |
| 3 | `/docs?name=` | Path traversal | `open` |
| 4 | `/hello?name=` | SSTI | `render_template_string` |
| 5 | `/fetch?url=` | SSRF | `requests.get` |
| – | `/order?id=` | **decoy** | same sink as #1, but sanitized upstream |

</details>

## Warning

These apps are deliberately broken. Run them in Docker only.

**Keep the `127.0.0.1:` prefix on every `-p`.** Without it Docker binds to all interfaces, and
anyone on the same wifi can reach `/ping?host=;…` on your laptop and run commands inside the
container. Same bug class as the ones you're about to find, one layer down.

## License

MIT
