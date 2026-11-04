#!/usr/bin/env python3
"""fk-remote — the round-27 run, live from the PC itself, in a browser on the LAN.
Shows the main run, every lane (state, last commit, notes), the lanes' questions with an answer box,
the newest renders from every lane, the design review pack, and lets the owner steer the run.
No arbitrary commands: only the fixed actions below. Token required (~/.config/fedokawaii/remote-token)."""
import hmac, json, os, re, subprocess, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs, unquote

HOME = Path.home()
REPO = HOME / "repos/fedokawaii"
LOG = HOME / ".cache/claude-r27.log"
INBOX = REPO / ".claude/inbox.md"
REVIEW = REPO / ".claude/review"            # the run publishes a pack here: current/NN-name.png + current/questions.md
FEEDBACK = REVIEW / "feedback.md"           # the owner's verdicts, read by the run
REG = HOME / ".config/fedokawaii/r27-lanes"  # the conductor's lane list (a leading # = paused)
CONDUCTOR = HOME / ".local/bin/r27-conductor"
CLOG = HOME / ".cache/r27-conductor.log"
ANSWERED = HOME / ".cache/fk-remote-answered.json"
TOKEN = (HOME / ".config/fedokawaii/remote-token").read_text().strip()
PAGE = (Path(__file__).parent / "index.html").read_bytes()
PORT = int(os.environ.get("FK_REMOTE_PORT", "8737"))
IMG = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".gif": "image/gif"}
NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,40}$")
DONE = re.compile(r"^[#*>\s]*(Status[*: ]*)?DONE[*.!]*\s*$", re.M)
LOCK = threading.Lock()                     # one writer at a time for the files we append to
_cache = {}

def sh(*args, timeout=10, cwd=None):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout, cwd=cwd).stdout
    except Exception as e:
        return f"({e})"

def cached(key, ttl, fn):
    now = time.time()
    hit = _cache.get(key)
    if hit and now - hit[0] < ttl:
        return hit[1]
    val = fn()
    _cache[key] = (now, val)
    return val

def read(p, tail=None):
    try:
        t = Path(p).read_text(errors="replace")
    except OSError:
        return ""
    return t[-tail:] if tail else t

def append(p, text):
    with LOCK:
        Path(p).parent.mkdir(parents=True, exist_ok=True)
        with open(p, "a") as f:
            f.write(text)

def stamp():
    return time.strftime("%Y-%m-%d %H:%M")

# ---------------------------------------------------------------- the machine
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

def memory():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        if v.strip().split():
            m[k] = int(v.split()[0]) // 1024
    total, avail = m.get("MemTotal", 0), m.get("MemAvailable", 0)
    return {"total": total, "used": total - avail, "avail": avail,
            "swap": m.get("SwapTotal", 0) - m.get("SwapFree", 0), "swap_total": m.get("SwapTotal", 0)}

def gpu():
    for p in Path("/sys/class/drm").glob("card*/device/gpu_busy_percent"):
        try:
            return p.read_text().strip()
        except OSError:
            pass
    return ""

# ---------------------------------------------------------------- the lanes
def registry():
    res = []
    for line in read(REG).splitlines():
        s = line.strip()
        if not s or s.startswith("# "):
            continue
        paused = s.startswith("#")
        parts = s.lstrip("#").split("|", 3)
        if len(parts) == 4 and NAME.match(parts[0]):
            res.append({"name": parts[0], "mode": parts[2], "paused": paused, "task": parts[3][:400]})
    return res

def lane_git(name):
    d = HOME / "repos" / f"fk-{name}"
    def f():
        last = sh("git", "-C", str(d), "log", "-1", "--format=%ad\t%s", "--date=format:%H:%M").strip()
        ahead = sh("git", "-C", str(d), "rev-list", "--count", "main..HEAD").strip()
        return {"last": last, "ahead": int(ahead) if ahead.isdigit() else 0}
    return cached("git:" + name, 30, f)

def lanes(units_now, agents_now):
    active = {u["unit"].removesuffix(".service") for u in units_now if u["active"] == "active"}
    reg = registry()
    known = {r["name"] for r in reg}
    for d in sorted((HOME / "repos").glob("fk-*")):
        n = d.name[3:]
        if n not in known and NAME.match(n):
            reg.append({"name": n, "mode": "lane", "paused": False, "task": "(not in the conductor's list)"})
    res = []
    for r in reg:
        n = r["name"]
        d = HOME / "repos" / f"fk-{n}"
        notes = read(d / ".claude/notes" / f"lane-{n}.md")
        ag = next((a for a in agents_now if a["who"] == "lane " + n), None)
        on = f"r27-lane-{n}" in active
        done = bool(DONE.search(notes))
        st = "done" if done else "paused" if r["paused"] else "working" if ag else "running" if on else "waiting" if d.exists() else "queued"
        tail = [l for l in notes.splitlines() if l.strip()][-8:]
        log = [l for l in read(HOME / ".cache" / f"claude-lane-{n}.log", 6000).splitlines() if l.strip()][-5:]
        res.append({**r, "state": st, "seconds": ag["seconds"] if ag else None, **(lane_git(n) if d.exists() else {"last": "", "ahead": 0}),
                    "notes": tail, "log": log})
    return res

def conductor(units_now):
    on = any(u["unit"].startswith("r27-lane-conductor") and u["active"] == "active" for u in units_now)
    m = re.search(r"MAXL=(\d+)", read(CONDUCTOR))
    return {"active": on, "maxl": int(m.group(1)) if m else None, "log": read(CLOG, 4000).splitlines()[-10:]}

# ---------------------------------------------------------------- questions and answers
def entries(text):
    """an inbox-style file as [(heading, body)], oldest first"""
    parts = re.split(r"^## (.+)$", text, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts) - 1, 2)]

def answered():
    try:
        return set(json.loads(read(ANSWERED) or "[]"))
    except ValueError:
        return set()

def qkey(head):
    return re.sub(r"[^\w]", "", head)[:120]

def questions():
    done = answered()
    res = []
    for head, body in entries(read(INBOX)):
        m = re.search(r"question from (lane-[a-z0-9-]+|main)", head, re.I)
        if not m or "answered" in head.lower() or qkey(head) in done:
            continue
        res.append({"key": qkey(head), "head": head, "body": body[:3000], "who": m.group(1).lower()})
    return res[::-1][:25]

def answer(key, text):
    text = str(text).strip()[:4000]
    q = next((q for q in questions() if q["key"] == key), None)
    if not q or not text:
        return False
    if q["who"].startswith("lane-"):
        n = q["who"][5:]
        notes = HOME / "repos" / f"fk-{n}" / ".claude/notes" / f"lane-{n}.md"
        if notes.parent.is_dir():
            append(notes, f"\n## OWNER ANSWER {stamp()} — to your question «{q['head']}»\n{text}\n")
    append(INBOX, f"\n## {stamp()} — open\nThe owner's answer to «{q['head']}» (also written into that lane's notes):\n{text}\n")
    with LOCK:
        a = answered(); a.add(key)
        ANSWERED.parent.mkdir(parents=True, exist_ok=True)
        ANSWERED.write_text(json.dumps(sorted(a)))
    return True

# ---------------------------------------------------------------- pictures
def picdir(src):
    if src == "current":
        return REVIEW / "current"
    if src == "main":
        return REPO / ".claude/review/next"
    if NAME.match(src):
        return HOME / "repos" / f"fk-{src}" / ".claude/review/next"
    return None

def gallery():
    def f():
        items = []
        srcs = ["main"] + [d.name[3:] for d in sorted((HOME / "repos").glob("fk-*")) if NAME.match(d.name[3:])]
        for s in srcs:
            d = picdir(s)
            if not d or not d.is_dir():
                continue
            for p in d.rglob("*"):
                if p.is_file() and p.suffix.lower() in IMG and p.relative_to(d).parts[0][:1] != ".":
                    st = p.stat()
                    items.append({"src": s, "file": str(p.relative_to(d)), "v": int(st.st_mtime), "kb": st.st_size // 1024})
        items.sort(key=lambda i: -i["v"])
        return items[:80]
    return cached("gallery", 15, f)

def review():
    cur = REVIEW / "current"
    items = []
    if cur.is_dir():
        for p in sorted(cur.iterdir()):
            if p.suffix.lower() in IMG:
                note = p.with_suffix(".md")
                items.append({"file": p.name, "title": p.stem, "v": int(p.stat().st_mtime),
                              "note": note.read_text(errors="replace")[:2000] if note.exists() else ""})
    q = cur / "questions.md"
    return {"items": items, "questions": q.read_text(errors="replace")[:6000] if q.exists() else "",
            "feedback": read(FEEDBACK, 20000)}

def verdicts():
    v = {}
    for head, body in entries(read(FEEDBACK)):
        p = [x.strip() for x in head.split("—")]
        if len(p) >= 3 and p[2] in ("love", "ok", "change", "redo"):
            v[p[1]] = {"v": p[2], "at": p[0][-5:], "text": body[:200]}
    return v

def add_feedback(item, verdict, text):
    item = re.sub(r"[^\w ./:-]", "", str(item))[:120] or "general"
    verdict = verdict if verdict in ("love", "ok", "change", "redo") else "comment"
    text = str(text).strip()[:4000]
    append(FEEDBACK, f"\n## {stamp()} — {item} — {verdict} — open\n{text}\n")
    m = re.match(r"next/([a-z0-9-]+)/(.+)$", item)
    if m and m.group(1) != "main":                  # a lane's render: the lane hears it directly too
        notes = HOME / "repos" / f"fk-{m.group(1)}" / ".claude/notes" / f"lane-{m.group(1)}.md"
        if notes.parent.is_dir():
            append(notes, f"\n## OWNER VERDICT {stamp()} on your render {m.group(2)}: {verdict}\n{text}\n")

def add_task(text):
    text = str(text).strip()[:4000]
    if text:
        append(INBOX, f"\n## {stamp()} — open\n{text}\n")

def set_paused(name, pause):
    if not NAME.match(str(name)):
        return False
    with LOCK:
        lines = read(REG).splitlines()
        hit = False
        for i, l in enumerate(lines):
            bare = l.lstrip("#")
            if bare.startswith(name + "|"):
                lines[i] = ("#" if pause else "") + bare
                hit = True
        if not hit:
            return False
        tmp = REG.with_suffix(".tmp")
        tmp.write_text("\n".join(lines) + "\n")
        os.replace(tmp, REG)
    if pause:
        sh("systemctl", "--user", "stop", f"r27-lane-{name}")
    _cache.clear()
    return True

# ---------------------------------------------------------------- the whole state
def plan():
    tasks, phase = [], ""
    for line in read(REPO / ".claude/plan.md").splitlines():
        m = re.match(r"^## (Phase.*)", line)
        if m:
            phase = m.group(1); continue
        m = re.match(r"^### (T[0-9A-Za-z]+)\s+—\s+(.*)$", line)
        if m:
            st = re.search(r"\[(done|todo|wip)[^\]]*\]\s*$", m.group(2), re.I)
            tasks.append({"phase": phase, "id": m.group(1), "title": re.sub(r"\s*\[[^\]]*\]\s*$", "", m.group(2)),
                          "state": st.group(1).lower() if st else "todo"})
    return tasks

def state():
    u, a = units(), agents()
    log = read(LOG, 20000).splitlines()[-60:]
    passes = [l for l in log if l.startswith("=== ")]
    main = next((x for x in a if x["who"] == "main"), None)
    return {
        "time": time.strftime("%a %d %b %H:%M:%S"),
        "units": u, "claude": main, "agents": a,
        "lanes": lanes(u, a), "conductor": conductor(u),
        "questions": questions(), "gallery": gallery(), "verdicts": verdicts(),
        "last_pass": passes[-1] if passes else "", "log": log[-40:],
        "commits": cached("commits", 10, lambda: sh("git", "-C", str(REPO), "log", "-25", "--format=%ad\t%s", "--date=format:%a %H:%M").splitlines()),
        "dirty": len(cached("dirty", 10, lambda: sh("git", "-C", str(REPO), "status", "--short")).splitlines()),
        "plan": cached("plan", 10, plan),
        "inbox": read(INBOX, 30000),
        "review": review(),
        "load": read("/proc/loadavg").split()[:3], "mem": memory(), "gpu": gpu(),
    }

# ---------------------------------------------------------------- actions
def stop_all(lanes_too=False):
    for x in units():
        if lanes_too or not x["unit"].startswith("r27-lane-"):
            sh("systemctl", "--user", "stop", x["unit"])
    sh("pkill", "-f", "^claude -p START")

def nonstop():
    stop_all()
    loop = ('cd ~/repos/fedokawaii; while [ ! -e .claude/DONE ]; do '
            'printf "\\n=== nonstop pass %(%F %T)T ===\\n" -1 >> ~/.cache/claude-r27.log; '
            'timeout 3h claude -p "START" --dangerously-skip-permissions --model opus --effort max >> ~/.cache/claude-r27.log 2>&1 || sleep 300; '
            'sleep 10; done')
    sh("systemd-run", "--user", f"--unit=r27-nonstop-{int(time.time())}", "bash", "-c", loop)

def bulk(hours):
    hours = max(1, min(int(hours), 24))
    stop_all()
    loop = ('cd ~/repos/fedokawaii; end=$((SECONDS+%d)); while ((SECONDS<end)) && [ ! -e .claude/DONE ]; do '
            'printf "\\n=== bulk pass %%(%%F %%T)T ===\\n" -1 >> ~/.cache/claude-r27.log; '
            'timeout 3h claude -p "START" --dangerously-skip-permissions --model opus --effort max >> ~/.cache/claude-r27.log 2>&1 || sleep 300; '
            'sleep 10; done; systemctl --user start claude-r27') % (hours * 3600)
    sh("systemd-run", "--user", f"--unit=r27-bulk-{int(time.time())}", "bash", "-c", loop)

def act(d):
    a = d.get("action")
    if a == "daily":
        stop_all(); sh("systemctl", "--user", "start", "claude-r27.service")
    elif a == "stop":
        stop_all(lanes_too=True)
    elif a == "newpass":
        sh("pkill", "-f", "^claude -p START")
    elif a == "nonstop":
        nonstop()
    elif a == "bulk":
        bulk(d.get("hours", 6))
    elif a == "conductor":
        sh("systemctl", "--user", "enable", "--now", "r27-lane-conductor.service")
    elif a == "feedback":
        add_feedback(d.get("item", ""), d.get("verdict", ""), d.get("text", ""))
    elif a == "task":
        add_task(d.get("text", ""))
    elif a == "answer":
        return answer(str(d.get("key", "")), d.get("text", ""))
    elif a in ("pause", "resume"):
        return set_paused(str(d.get("lane", "")), a == "pause")
    else:
        return None
    return True

# ---------------------------------------------------------------- http
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def authed(self, t=None):
        t = t if t is not None else self.headers.get("X-Token", "")
        return bool(t) and hmac.compare_digest(t, TOKEN)
    def send(self, code, body, ctype="application/json", cache="no-store"):
        b = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", cache)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        try:
            self.wfile.write(b)
        except (BrokenPipeError, ConnectionResetError):
            pass
    def picture(self, src, name, token):
        if not self.authed(token):
            return self.send(401, {"error": "token"})
        base = picdir(src)
        if not base or ".." in Path(name).parts:
            return self.send(404, {"error": "no"})
        f = (base / name).resolve()
        if not str(f).startswith(str(base.resolve()) + os.sep) or not f.is_file() or f.suffix.lower() not in IMG:
            return self.send(404, {"error": "no"})
        return self.send(200, f.read_bytes(), IMG[f.suffix.lower()], "private, max-age=86400")
    def do_GET(self):
        u = urlparse(self.path)
        t = parse_qs(u.query).get("t", [""])[0]
        if u.path in ("/", "/index.html"):
            return self.send(200, PAGE, "text/html; charset=utf-8")
        if u.path.startswith("/review/"):                     # the old address: the current pack
            return self.picture("current", unquote(u.path[len("/review/"):]), t)
        if u.path.startswith("/img/"):
            src, _, name = unquote(u.path[len("/img/"):]).partition("/")
            return self.picture(src, name, t)
        if u.path == "/api/state":
            if not self.authed():
                return self.send(401, {"error": "token"})
            try:
                return self.send(200, state())
            except Exception as e:                            # never a dead page: say what broke
                return self.send(500, {"error": f"state: {e}"})
        self.send(404, {"error": "no"})
    def do_POST(self):
        if not self.authed():
            return self.send(401, {"error": "token"})
        n = min(int(self.headers.get("Content-Length", "0") or 0), 40000)
        try:
            d = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self.send(400, {"error": "json"})
        try:
            r = act(d)
        except Exception as e:
            return self.send(500, {"error": str(e)})
        if r is None:
            return self.send(400, {"error": "action"})
        _cache.pop("gallery", None)
        self.send(200 if r else 409, {"ok": bool(r)})

ThreadingHTTPServer.daemon_threads = True
ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
