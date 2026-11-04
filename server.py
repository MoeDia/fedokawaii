#!/usr/bin/env python3
"""fk-remote — the round-27 run, live from the PC itself, in a browser on the LAN.
Shows what the run is doing and lets the owner start/stop it, run a bulk session and add
tasks (to .claude/inbox.md, which the run reads at the start of every pass).
No arbitrary commands: only the fixed actions below. Token required (~/.config/fedokawaii/remote-token)."""
import hmac, json, os, re, subprocess, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOME = Path.home()
REPO = HOME / "repos/fedokawaii"
LOG = HOME / ".cache/claude-r27.log"
INBOX = REPO / ".claude/inbox.md"
REVIEW = REPO / ".claude/review"            # the run publishes a pack here: current/NN-name.png + current/questions.md
FEEDBACK = REVIEW / "feedback.md"           # the owner's verdicts, read by the run
TOKEN = (HOME / ".config/fedokawaii/remote-token").read_text().strip()
PAGE = (Path(__file__).parent / "index.html").read_bytes()
PORT = int(os.environ.get("FK_REMOTE_PORT", "8737"))

def sh(*args, timeout=10):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except Exception as e:
        return f"({e})"

def units():
    out = sh("systemctl", "--user", "list-units", "--all", "--no-legend", "--plain", "claude-r27.service", "r27-*")
    res = []
    for line in out.splitlines():
        p = line.split(None, 4)
        if len(p) >= 4:
            res.append({"unit": p[0], "active": p[2], "sub": p[3]})
    return res

def agents():
    """every running `claude -p` agent: which lane (by its folder) and for how long"""
    res = []
    for pid in sh("pgrep", "-f", "^claude -p ").split():
        if not pid.isdigit():
            continue
        try:
            cwd = os.readlink(f"/proc/{pid}/cwd")
        except OSError:
            continue
        et = sh("ps", "-o", "etimes=", "-p", pid).strip()
        name = "main" if cwd.rstrip("/").endswith("/fedokawaii") else os.path.basename(cwd).replace("fk-", "lane ")
        res.append({"pid": int(pid), "who": name, "seconds": int(et) if et.isdigit() else None})
    return res

def claude_proc():
    m = [a for a in agents() if a["who"] == "main"]
    return m[0] if m else None

def lanes():
    out = {}
    for f in sorted((HOME / ".cache").glob("claude-lane-*.log")):
        name = f.stem.replace("claude-lane-", "")
        out[name] = f.read_text(errors="replace").splitlines()[-12:]
    return out

def plan():
    f = REPO / ".claude/plan.md"
    if not f.exists():
        return []
    tasks, phase = [], ""
    for line in f.read_text(errors="replace").splitlines():
        m = re.match(r"^## (Phase.*)", line)
        if m:
            phase = m.group(1); continue
        m = re.match(r"^### (T[0-9A-Za-z]+)\s+—\s+(.*)$", line)
        if m:
            st = re.search(r"\[(done|todo|wip)[^\]]*\]\s*$", m.group(2), re.I)
            state = st.group(1).lower() if st else "todo"
            tasks.append({"phase": phase, "id": m.group(1), "title": re.sub(r"\s*\[[^\]]*\]\s*$", "", m.group(2)), "state": state})
    return tasks

def state():
    log = LOG.read_text(errors="replace").splitlines()[-60:] if LOG.exists() else []
    passes = [l for l in log if l.startswith("=== ")]
    mem = sh("free", "-m").splitlines()
    gpu = ""
    for p in Path("/sys/class/drm").glob("card*/device/gpu_busy_percent"):
        gpu = p.read_text().strip(); break
    return {
        "time": time.strftime("%a %d %b %H:%M:%S"),
        "units": units(),
        "claude": claude_proc(),
        "agents": agents(),
        "lanes": lanes(),
        "last_pass": passes[-1] if passes else "",
        "log": log[-40:],
        "commits": sh("git", "-C", str(REPO), "log", "-20", "--format=%ad\t%s", "--date=format:%a %H:%M").splitlines(),
        "dirty": len(sh("git", "-C", str(REPO), "status", "--short").splitlines()),
        "plan": plan(),
        "inbox": INBOX.read_text(errors="replace")[-4000:] if INBOX.exists() else "",
        "review": review(),
        "load": Path("/proc/loadavg").read_text().split()[:3],
        "mem": mem[1].split()[1:3] if len(mem) > 1 else [],
        "gpu": gpu,
    }

def stop_all(lanes_too=False):
    for u in units():
        if lanes_too or not u["unit"].startswith("r27-lane-"):
            sh("systemctl", "--user", "stop", u["unit"])
    sh("pkill", "-f", "^claude -p START")

def nonstop():
    stop_all()
    loop = ('cd ~/repos/fedokawaii; while [ ! -e .claude/DONE ]; do '
            'printf "\\n=== nonstop pass %(%F %T)T ===\\n" -1 >> ~/.cache/claude-r27.log; '
            'timeout 3h claude -p "START" --dangerously-skip-permissions --model opus --effort max >> ~/.cache/claude-r27.log 2>&1 || sleep 300; '
            'sleep 10; done')
    sh("systemd-run", "--user", f"--unit=r27-nonstop-{int(time.time())}", "bash", "-c", loop)

ACTIONS = {
    "daily":   lambda d: (stop_all(), sh("systemctl", "--user", "start", "claude-r27.service")),
    "stop":    lambda d: stop_all(lanes_too=True),
    "newpass": lambda d: sh("pkill", "-f", "^claude -p START"),
    "nonstop": lambda d: nonstop(),
}

def bulk(hours):
    hours = max(1, min(int(hours), 24))
    stop_all()
    loop = ('cd ~/repos/fedokawaii; end=$((SECONDS+%d)); while ((SECONDS<end)) && [ ! -e .claude/DONE ]; do '
            'printf "\\n=== bulk pass %%(%%F %%T)T ===\\n" -1 >> ~/.cache/claude-r27.log; '
            'timeout 3h claude -p "START" --dangerously-skip-permissions --model opus --effort max >> ~/.cache/claude-r27.log 2>&1 || sleep 300; '
            'sleep 10; done; systemctl --user start claude-r27') % (hours * 3600)
    sh("systemd-run", "--user", f"--unit=r27-bulk-{int(time.time())}", "bash", "-c", loop)

def review():
    cur = REVIEW / "current"
    items = []
    if cur.is_dir():
        for p in sorted(cur.iterdir()):
            if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                note = p.with_suffix(".md")
                items.append({"file": p.name, "title": p.stem, "note": note.read_text(errors="replace")[:2000] if note.exists() else ""})
    q = cur / "questions.md"
    return {"items": items, "questions": q.read_text(errors="replace")[:6000] if q.exists() else "",
            "feedback": FEEDBACK.read_text(errors="replace")[-6000:] if FEEDBACK.exists() else ""}

def add_feedback(item, verdict, text):
    REVIEW.mkdir(parents=True, exist_ok=True)
    item = re.sub(r"[^\w .-]", "", str(item))[:80] or "general"
    verdict = verdict if verdict in ("love", "ok", "change", "redo") else "comment"
    with FEEDBACK.open("a") as f:
        f.write(f"\n## {time.strftime('%Y-%m-%d %H:%M')} — {item} — {verdict} — open\n{str(text).strip()[:4000]}\n")

def add_task(text):
    text = text.strip()[:4000]
    if not text:
        return
    INBOX.parent.mkdir(parents=True, exist_ok=True)
    with INBOX.open("a") as f:
        f.write(f"\n## {time.strftime('%Y-%m-%d %H:%M')} — open\n{text}\n")

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def authed(self):
        t = self.headers.get("X-Token", "")
        return bool(t) and hmac.compare_digest(t, TOKEN)
    def send(self, code, body, ctype="application/json"):
        b = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            return self.send(200, PAGE, "text/html; charset=utf-8")
        if self.path.startswith("/review/"):
            from urllib.parse import urlparse, parse_qs, unquote
            u = urlparse(self.path)
            t = parse_qs(u.query).get("t", [""])[0]
            if not (t and hmac.compare_digest(t, TOKEN)):
                return self.send(401, {"error": "token"})
            name = unquote(u.path[len("/review/"):])
            f = (REVIEW / "current" / name).resolve()
            if f.parent != (REVIEW / "current").resolve() or not f.is_file():
                return self.send(404, {"error": "no"})
            ctype = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(f.suffix.lower())
            return self.send(200, f.read_bytes(), ctype) if ctype else self.send(404, {"error": "no"})
        if self.path == "/api/state":
            return self.send(200, state()) if self.authed() else self.send(401, {"error": "token"})
        self.send(404, {"error": "no"})
    def do_POST(self):
        if not self.authed():
            return self.send(401, {"error": "token"})
        n = min(int(self.headers.get("Content-Length", "0") or 0), 20000)
        try:
            d = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self.send(400, {"error": "json"})
        a = d.get("action")
        if a in ACTIONS:
            ACTIONS[a](d)
        elif a == "bulk":
            bulk(d.get("hours", 6))
        elif a == "feedback":
            add_feedback(d.get("item", ""), d.get("verdict", ""), d.get("text", ""))
        elif a == "task":
            add_task(str(d.get("text", "")))
        else:
            return self.send(400, {"error": "action"})
        self.send(200, {"ok": True})

ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
