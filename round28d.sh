#!/usr/bin/env bash
# round28d.sh (owner, 6 Nov 00:27-00:32): the 100-hour run, unattended and watched.
#   - the old control page is retired; a read-only tracker takes port 8737 (r28-track)
#   - every 30 min r28-pulse repairs what died, brings Claude's steering into the inbox and pushes the
#     status to GitHub (branch pulse), where Claude watches the run from his chat
#   - the screen sleeps and the RGB stays off (r28-dark); nothing asks for a password for 4 days
# Run as dia from a terminal in his session. sudo may ask for the password ONCE, now, never again.
set +e
[ "$(id -u)" = 0 ] && { echo "run as dia, not root"; exit 1; }
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
R=$HOME/repos/fedokawaii; B=$HOME/.local/bin; U=$HOME/.config/systemd/user; S=$HOME/.local/share/r28
mkdir -p "$B" "$U" "$S/img" "$HOME/.config/fedokawaii"
say(){ printf '\033[1;31m== %s\033[0m\n' "$*"; }

say "1/6 round 28's brief (round28c), if it is not in yet"
grep -q "ROUND 28 — THE OWNER'S BRIEF" "$R/.claude/inbox.md" 2>/dev/null && echo "already in" \
  || curl -sL https://raw.githubusercontent.com/MoeDia/fedokawaii/remote/round28c.sh | bash

say "2/6 no password for 4 days (round rules: removed at T62, never in the ISO)"
if ! sudo -n true 2>/dev/null; then
  printf '# round 28 only (owner, 6 Nov 2026): remove at T62, never in the ISO or the installer\n%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" \
    | sudo tee /etc/sudoers.d/00-fedokawaii-r28 >/dev/null
  sudo chmod 440 /etc/sudoers.d/00-fedokawaii-r28
  sudo visudo -cqf /etc/sudoers.d/00-fedokawaii-r28 || sudo rm -f /etc/sudoers.d/00-fedokawaii-r28
fi
[ -e /etc/polkit-1/rules.d/00-fedokawaii-round.rules ] || printf '%s\n' \
  '// round 28 only (owner, 6 Nov 2026): no password pop-ups for dia. Remove at T62, never in the ISO.' \
  'polkit.addRule(function(action, subject) { if (subject.user == "dia") { return polkit.Result.YES; } });' \
  | sudo tee /etc/polkit-1/rules.d/00-fedokawaii-round.rules >/dev/null
loginctl enable-linger "$(id -un)" 2>/dev/null || sudo loginctl enable-linger "$(id -un)"
command -v wlopm >/dev/null && command -v swayidle >/dev/null || sudo dnf -y -q install wlopm swayidle

say "3/6 the old page goes"
systemctl --user disable --now fk-remote 2>/dev/null
[ -d "$HOME/.local/share/fedokawaii/remote" ] && mv "$HOME/.local/share/fedokawaii/remote" "$HOME/.local/share/fedokawaii/retired-remote-r27-$(date +%H%M)"
rm -f "$U/fk-remote.service"

say "4/6 the tracker, the pulse, the dark"
cat > "$B/r28-track" <<'r28_track_EOF'
#!/usr/bin/env python3
"""r28-track: the round-28 tracker (owner, 6 Nov 2026).

A read-only page on port 8737 for the owner, and the same status as JSON and markdown
for r28-pulse, which pushes it to GitHub (branch `pulse`) where Claude watches it.
It only reads: the plan the run keeps, git, the Claude Code transcripts (tokens), the
journal and the sensors. Remove at T62; never in the ISO.

  r28-track                    serve
  r28-track --json [--quick]   one status (--quick skips the token count)
  r28-track --md [--quick]     the same as markdown
"""
import glob, json, os, re, subprocess, sys, threading, time
from datetime import datetime, timedelta, timezone
from urllib.parse import unquote
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOME = os.path.expanduser("~")
REPO = f"{HOME}/repos/fedokawaii"
PLAN = f"{REPO}/.claude/notes/r28-plan.tsv"
STATE = f"{HOME}/.local/share/r28"
IMG = f"{STATE}/img"
DXB = timezone(timedelta(hours=4))
START = datetime(2026, 11, 6, 0, 30, tzinfo=DXB)
END = START + timedelta(hours=100)
START_UTC = START.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M")
PORT = 8737
STATUSES = ("now", "todo", "blocked", "owner", "done")
SECRETISH = re.compile(r"[A-Za-z0-9_\-+/=]{32,}")


def sh(cmd, timeout=10):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def clean(text):
    return SECRETISH.sub("[…]", text)[:220]


# ── the plan: .claude/notes/r28-plan.tsv, one small task per line ───────────────────────────
# id <TAB> day <TAB> status <TAB> task <TAB> when <TAB> note      status: now todo done blocked owner
def plan():
    rows = []
    for line in read(PLAN).splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        f = [c.strip() for c in (line.split("\t") + [""] * 6)[:6]]
        if f[0].lower() == "id":
            continue
        st = f[2].lower()
        rows.append({"id": f[0], "day": f[1], "status": st if st in STATUSES else "todo",
                     "task": f[3], "when": f[4], "note": clean(f[5])})
    return rows


def pace(rows, now):
    total, done = len(rows), sum(r["status"] == "done" for r in rows)
    left = sum(r["status"] in ("now", "todo") for r in rows)
    hours = max((now - START).total_seconds() / 3600, 0)
    used = min(hours / 100, 1)
    share = done / total if total else 0
    eta = (now + timedelta(hours=left * hours / done)).isoformat(timespec="minutes") if done and hours > 0.5 else None
    return {"total": total, "done": done, "left": left,
            "blocked": sum(r["status"] == "blocked" for r in rows),
            "owner": sum(r["status"] == "owner" for r in rows),
            "share": round(share, 3), "time_used": round(used, 3),
            "ahead_h": round((share - used) * 100, 1) if total else None, "eta": eta,
            "ready_for_owner": total > 0 and left == 0}


# ── the machine ─────────────────────────────────────────────────────────────────────────────
def temps():
    out = {}
    for d in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read(f"{d}/name").strip()
        if name not in ("k10temp", "amdgpu", "nvme"):
            continue
        for t in glob.glob(f"{d}/temp*_input"):
            label = read(t.replace("_input", "_label")).strip() or "temp"
            try:
                c = round(int(read(t).strip()) / 1000)
            except ValueError:
                continue
            key = {"k10temp": "cpu", "amdgpu": "gpu", "nvme": "ssd"}[name] + " " + label.lower()
            out[key] = max(out.get(key, 0), c)          # two amdgpu (iGPU and card): the hotter one
    return dict(sorted(out.items()))


def machine():
    mem = dict(re.findall(r"(\w+):\s+(\d+)", read("/proc/meminfo")))
    st = os.statvfs(HOME)
    return {"load": read("/proc/loadavg").split()[:3], "cores": os.cpu_count(),
            "mem_free_gb": round(int(mem.get("MemAvailable", 0)) / 2**20, 1),
            "mem_total_gb": round(int(mem.get("MemTotal", 0)) / 2**20),
            "disk_free_gb": round(st.f_bavail * st.f_frsize / 2**30),
            "uptime_h": round(float((read("/proc/uptime").split() or ["0"])[0]) / 3600, 1),
            "temps": temps()}


def run(now):
    ages = [int(a) for a in (sh(f"ps -o etimes= -p {p}") for p in sh("pgrep -f '^claude -p'").split()) if a.isdigit()]
    units = sh("systemctl --user is-active r27-lane-conductor r28-dark r28-pulse.timer").split() + ["?"] * 3
    commits = []
    for line in sh(f"git -C {REPO} log --branches --since='{START.isoformat()}' --format='%h%x09%ct%x09%s' -n 300").splitlines():
        h, t, s = (line.split("\t") + ["", "0", ""])[:3]
        commits.append({"h": h, "t": int(t or 0), "s": clean(s)})
    errs = [clean(l) for l in sh("journalctl --user --since '-2 hours' -p err -o cat --no-pager | tail -n 40").splitlines()]
    return {"passes": len(ages), "oldest_pass_min": max(ages) // 60 if ages else 0,
            "conductor": units[0], "dark_unit": units[1], "pulse_timer": units[2],
            "dark": os.path.exists(f"{HOME}/.config/fedokawaii/dark"),
            "hold": os.path.exists(f"{STATE}/hold"),
            "commits_since_start": len(commits), "commits": commits[:14],
            "last_commit": commits[0]["t"] if commits else 0,
            "errors_2h": len(errs), "errors": errs[-4:],
            "repairs": read(f"{STATE}/repairs.log").splitlines()[-6:],
            "steer_seen": read(f"{STATE}/steer-seen").split()[-8:]}


def options():
    caps = {}
    for line in read(f"{IMG}/captions.txt").splitlines():
        if line.strip():
            k, _, v = line.strip().partition(" ")
            caps[k] = v.strip()
    files = sorted(f for f in os.listdir(IMG) if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))) if os.path.isdir(IMG) else []
    return [{"file": f, "caption": caps.get(f, "")} for f in files]


# ── tokens: the run's Claude Code transcripts, read incrementally ───────────────────────────
class Tokens:
    def __init__(self):
        self.pos, self.seen, self.hours, self.limits = {}, set(), {}, []
        self.tot = {"out": 0, "in": 0, "cache_read": 0, "cache_write": 0, "msgs": 0}
        self.newest = 0.0

    def scan(self, count=True):
        t0 = START.timestamp()
        for f in glob.glob(f"{HOME}/.claude/projects/**/*.jsonl", recursive=True):
            try:
                st = os.stat(f)
            except OSError:
                continue
            self.newest = max(self.newest, st.st_mtime)
            if not count or st.st_mtime < t0:
                continue
            pos = self.pos.get(f, 0)
            if st.st_size < pos:
                pos = 0
            if st.st_size == pos:
                continue
            with open(f, "rb") as fh:
                fh.seek(pos)
                data = fh.read()
            cut = data.rfind(b"\n") + 1
            self.pos[f] = pos + cut
            for raw in data[:cut].splitlines():
                if b'"usage"' in raw or b"<synthetic>" in raw:
                    self.line(raw)

    def line(self, raw):
        try:
            o = json.loads(raw)
        except ValueError:
            return
        ts = str(o.get("timestamp", ""))
        if ts and ts < START_UTC:
            return
        m = o.get("message") if isinstance(o.get("message"), dict) else {}
        if m.get("model") == "<synthetic>" and b"limit" in raw.lower():
            self.limits.append(ts[:16])
            return
        u = m.get("usage")
        mid = m.get("id") or o.get("uuid")
        if not isinstance(u, dict) or mid in self.seen:
            return
        self.seen.add(mid)
        n = {"out": u.get("output_tokens", 0), "in": u.get("input_tokens", 0),
             "cache_read": u.get("cache_read_input_tokens", 0), "cache_write": u.get("cache_creation_input_tokens", 0)}
        for k, v in n.items():
            self.tot[k] += int(v or 0)
        self.tot["msgs"] += 1
        h = self.hours.setdefault(ts[:13], [0, 0])
        h[0] += int(n["out"] or 0)
        h[1] += sum(int(v or 0) for v in n.values())

    def view(self):
        now = datetime.now(timezone.utc)
        last24 = []
        for i in range(23, -1, -1):
            t = now - timedelta(hours=i)
            out, total = self.hours.get(t.strftime("%Y-%m-%dT%H"), [0, 0])
            last24.append({"h": t.astimezone(DXB).strftime("%H"), "out": out, "total": total})
        return {"total": dict(self.tot), "last24": last24, "limit_hits": len(self.limits),
                "last_limit": self.limits[-1] if self.limits else None}


def collect(tok, count=True):
    now = datetime.now(DXB)
    tok.scan(count)
    rows = plan()
    r = run(now)
    r["last_activity_min"] = round((time.time() - max(tok.newest, r["last_commit"])) / 60) if tok.newest or r["last_commit"] else None
    s = {"at": now.isoformat(timespec="seconds"), "start": START.isoformat(), "end": END.isoformat(),
         "pace": pace(rows, now), "plan": rows, "machine": machine(), "run": r,
         "tokens": tok.view() if count else None, "options": options()}
    s["alerts"] = alerts(s)
    return s


def alerts(s):
    a, m, r, p = [], s["machine"], s["run"], s["pace"]
    if r["conductor"] != "active" and not r["hold"]:
        a.append(("bad", "the run is not running"))
    if r["hold"]:
        a.append(("warn", "on hold (resting on purpose)"))
    if r["last_activity_min"] is not None and r["last_activity_min"] > 45 and not r["hold"]:
        a.append(("bad", f"quiet for {r['last_activity_min']} min"))
    if p["ahead_h"] is not None and p["ahead_h"] < -6:
        a.append(("warn", f"behind by {-p['ahead_h']:.0f} h"))
    if p["blocked"]:
        a.append(("warn", f"{p['blocked']} blocked"))
    if m["disk_free_gb"] < 25:
        a.append(("bad", f"disk {m['disk_free_gb']} GB free"))
    if m["mem_free_gb"] < 4:
        a.append(("bad", f"memory {m['mem_free_gb']} GB free"))
    hot = [f"{k} {v}°" for k, v in m["temps"].items() if v >= 90]
    if hot:
        a.append(("bad", "hot: " + ", ".join(hot)))
    if s["tokens"] and s["tokens"]["limit_hits"]:
        a.append(("warn", f"usage limit hit {s['tokens']['limit_hits']}× (last {s['tokens']['last_limit']} UTC)"))
    if r["errors_2h"]:
        a.append(("warn", f"{r['errors_2h']} errors in 2 h"))
    if p["ready_for_owner"]:
        a.append(("ok", "READY FOR THE OWNER"))
    return a


def md(s):
    p, m, r, t = s["pace"], s["machine"], s["run"], s["tokens"]
    when = lambda iso: datetime.fromisoformat(iso).strftime("%a %d %H:%M") if iso else "—"
    lines = [f"# round 28 pulse · {when(s['at'])} (Dubai)", "",
             f"pace: {p['done']}/{p['total']} done ({p['share']:.0%}) · time used {p['time_used']:.0%} · "
             f"ahead {p['ahead_h']} h · ETA {when(p['eta'])} · left {p['left']} · blocked {p['blocked']} · owner {p['owner']}",
             "alerts: " + ("; ".join(x[1] for x in s["alerts"]) or "none"),
             f"run: conductor {r['conductor']} · passes {r['passes']} (oldest {r['oldest_pass_min']} min) · last activity "
             f"{r['last_activity_min']} min ago · commits since start {r['commits_since_start']} · hold {r['hold']}",
             f"machine: load {' '.join(m['load'])}/{m['cores']} · mem free {m['mem_free_gb']} GB · disk free {m['disk_free_gb']} GB · "
             f"up {m['uptime_h']} h · " + " · ".join(f"{k} {v}°" for k, v in m["temps"].items()),
             f"dark: {r['dark']} ({r['dark_unit']}) · pulse timer {r['pulse_timer']}"]
    if t:
        tt = t["total"]
        lines.append(f"tokens since start: out {tt['out']:,} · in {tt['in']:,} · cache write {tt['cache_write']:,} · "
                     f"cache read {tt['cache_read']:,} · msgs {tt['msgs']} · out last 6 h {sum(h['out'] for h in t['last24'][-6:]):,}")
    lines += ["", "## now / blocked / owner"]
    lines += [f"- [{x['status']}] {x['id']} {x['task']} — {x['note']}" for x in s["plan"] if x["status"] in ("now", "blocked", "owner")]
    lines += ["", "## last done"]
    lines += [f"- {x['id']} {x['task']} ({x['when']})" for x in [x for x in s["plan"] if x["status"] == "done"][-6:]]
    lines += ["", "## commits"] + [f"- {datetime.fromtimestamp(c['t'], DXB):%a %H:%M} {c['h']} {c['s']}" for c in r["commits"][:8]]
    lines += ["", "## repairs"] + [f"- {x}" for x in r["repairs"]]
    lines += ["", "## errors (2 h)"] + [f"- {x}" for x in r["errors"]]
    lines += ["", f"steering received: {' '.join(r['steer_seen']) or 'none'}",
              f"options: {', '.join(o['file'] for o in s['options']) or 'none yet'}"]
    return "\n".join(lines) + "\n"


# ── the page ────────────────────────────────────────────────────────────────────────────────
PAGE = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>round 28</title><style>
:root{--ink:#110d0c;--panel:#1b1513;--line:#382a24;--paper:#efe6d2;--dim:#9d8f80;--red:#e0533a;--gold:#d4ae63;--ok:#93b878;--warn:#e6a53c}
*{box-sizing:border-box}html,body{margin:0;background:var(--ink);color:var(--paper);font:15px/1.5 "Iosevka","JetBrains Mono","DejaVu Sans Mono",monospace}
main{max-width:1180px;margin:0 auto;padding:22px 16px 64px}
header{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:baseline;gap:8px 20px;border-bottom:1px solid var(--line);padding-bottom:12px}
h1{margin:0;font:600 24px/1 "Noto Serif JP","Noto Serif",serif;letter-spacing:.05em}h1 b{color:var(--red);font-weight:700}
.clock{color:var(--dim)}.clock b{color:var(--paper);font-size:19px}
.hero{display:grid;grid-template-columns:auto 1fr;gap:28px;align-items:center;margin:24px 0 8px}
.big{font-size:72px;line-height:.9;font-weight:700}.big small{display:block;font-size:14px;color:var(--dim);font-weight:400;margin-top:8px}
.bars .row{display:grid;grid-template-columns:48px 1fr 56px;gap:10px;align-items:center;margin:7px 0;color:var(--dim)}
.bar{height:12px;background:#2b211c;border-radius:6px;overflow:hidden}.bar i{display:block;height:100%;background:var(--red)}.bar.t i{background:var(--gold)}
.verdict{margin-top:10px;font-weight:600}.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--red)}
.alerts{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0 4px}.alert{border:1px solid currentColor;border-radius:999px;padding:3px 11px;font-size:13px}
.cols{display:grid;grid-template-columns:1.45fr 1fr;gap:30px}@media(max-width:860px){.cols,.hero{grid-template-columns:1fr}.big{font-size:56px}}
section{margin-top:26px}h2{margin:0 0 10px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--gold)}
.now{border-left:3px solid var(--red);background:var(--panel);border-radius:0 10px 10px 0;padding:9px 13px;margin:6px 0}.now .n{color:var(--dim);font-size:13px}
.day h3{display:flex;justify-content:space-between;margin:16px 0 4px;font-size:13px;color:var(--dim);font-weight:600}
.task{display:grid;grid-template-columns:18px 46px 1fr;gap:8px;padding:5px 0;border-bottom:1px dashed #2b211c}
.task .id{color:var(--dim);font-size:12px;padding-top:2px}.task .note{display:block;color:var(--dim);font-size:13px}
.s-done .t{color:var(--dim);text-decoration:line-through;text-decoration-color:#5d4b41}.g{text-align:center}
.s-done .g{color:var(--ok)}.s-now .g{color:var(--red)}.s-blocked .g{color:var(--warn)}.s-owner .g{color:var(--gold)}.s-todo .g{color:#5d4b41}
.tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:8px}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 11px}.tile .k{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--dim)}.tile .v{font-size:19px;font-weight:600}
.spark{display:flex;align-items:flex-end;gap:3px;height:64px;margin:8px 0 2px}.spark i{flex:1;background:var(--red);border-radius:2px 2px 0 0;min-height:1px;opacity:.85}
.hrs{display:flex;justify-content:space-between;color:var(--dim);font-size:11px}
ul{list-style:none;margin:0;padding:0}li{padding:4px 0;border-bottom:1px dashed #2b211c;font-size:13.5px}li .w{color:var(--dim);margin-right:8px}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}.gallery figure{margin:0;background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden}
.gallery img{width:100%;display:block}.gallery figcaption{padding:7px 10px;font-size:13px}.gallery b{color:var(--gold)}
.foot{margin-top:30px;color:var(--dim);font-size:12px}.empty{color:var(--dim)}
</style></head><body><main id="app"><p class="empty">reading the run…</p></main><script>
const E=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const G={done:"✓",now:"▶",todo:"·",blocked:"✕",owner:"?"};
const day=i=>new Date(i).toLocaleString("en-GB",{weekday:"short",day:"2-digit",hour:"2-digit",minute:"2-digit",timeZone:"Asia/Dubai"});
const left=s=>{const ms=new Date(s.end)-new Date();if(ms<=0)return"time is up";const h=Math.floor(ms/36e5),m=Math.floor(ms%36e5/6e4);return`${h} h ${m} min left`};
function render(s){const p=s.pace,m=s.machine,r=s.run,t=s.tokens;
const ah=p.ahead_h,v=ah==null?["warn","waiting for the plan"]:Math.abs(ah)<2?["ok","on track"]:ah>0?["ok",`ahead by ${ah} h`]:["bad",`behind by ${-ah} h`];
const byDay={};s.plan.forEach(x=>(byDay[x.day||"—"]=byDay[x.day||"—"]||[]).push(x));
const now=s.plan.filter(x=>x.status==="now");
const temps=Object.entries(m.temps).map(([k,v])=>`<div class="tile"><div class="k">${E(k)}</div><div class="v ${v>=90?"bad":v>=80?"warn":""}">${v}°</div></div>`).join("");
const mx=t?Math.max(1,...t.last24.map(h=>h.out)):1;
document.getElementById("app").innerHTML=`
<header><h1><b>参</b> round 28 · the 100-hour run</h1><div class="clock"><b>${left(s)}</b> · ends ${day(s.end)}</div></header>
<div class="hero"><div class="big">${Math.round(p.share*100)}%<small>${p.done} of ${p.total} tasks done</small></div>
<div class="bars"><div class="row"><span>work</span><div class="bar"><i style="width:${p.share*100}%"></i></div><span>${Math.round(p.share*100)}%</span></div>
<div class="row"><span>time</span><div class="bar t"><i style="width:${p.time_used*100}%"></i></div><span>${Math.round(p.time_used*100)}%</span></div>
<div class="verdict ${v[0]}">${v[1]}${p.eta?` · at this pace done ${day(p.eta)}`:""}</div></div></div>
<div class="alerts">${s.alerts.map(a=>`<span class="alert ${a[0]}">${E(a[1])}</span>`).join("")||'<span class="alert ok">all well</span>'}</div>
<div class="cols"><div>
<section><h2>now</h2>${now.map(x=>`<div class="now">${E(x.task)} <span class="n">${E(x.id)}</span>${x.note?`<div class="n">${E(x.note)}</div>`:""}</div>`).join("")||'<p class="empty">between tasks</p>'}
<p class="empty">${r.passes} pass${r.passes==1?"":"es"} running${r.passes?` (${r.oldest_pass_min} min)`:""} · last activity ${r.last_activity_min??"—"} min ago · ${r.commits_since_start} commits since the start</p></section>
<section><h2>the plan</h2>${Object.entries(byDay).map(([d,xs])=>`<div class="day"><h3><span>${E(d)}</span><span>${xs.filter(x=>x.status==="done").length}/${xs.length}</span></h3>
${xs.map(x=>`<div class="task s-${x.status}"><span class="g">${G[x.status]}</span><span class="id">${E(x.id)}</span><span><span class="t">${E(x.task)}</span>${x.note?`<span class="note">${E(x.note)}</span>`:""}</span></div>`).join("")}</div>`).join("")||'<p class="empty">the run writes its plan first</p>'}</section>
</div><div>
<section><h2>the machine</h2><div class="tiles">${temps}
<div class="tile"><div class="k">load</div><div class="v">${E(m.load[0])}<small style="color:var(--dim)">/${m.cores}</small></div></div>
<div class="tile"><div class="k">memory free</div><div class="v ${m.mem_free_gb<4?"bad":""}">${m.mem_free_gb} GB</div></div>
<div class="tile"><div class="k">disk free</div><div class="v ${m.disk_free_gb<25?"bad":""}">${m.disk_free_gb} GB</div></div>
<div class="tile"><div class="k">up</div><div class="v">${m.uptime_h} h</div></div>
<div class="tile"><div class="k">the run</div><div class="v ${r.conductor==="active"?"ok":"bad"}">${E(r.conductor)}</div></div>
<div class="tile"><div class="k">screen &amp; rgb</div><div class="v">${r.dark?"dark":"normal"}</div></div></div></section>
${t?`<section><h2>tokens · last 24 h (output)</h2><div class="spark">${t.last24.map(h=>`<i title="${h.h}:00 · ${h.out.toLocaleString()} out" style="height:${h.out/mx*100}%"></i>`).join("")}</div>
<div class="hrs"><span>${t.last24[0].h}:00</span><span>now</span></div>
<p class="empty">since the start: ${t.total.out.toLocaleString()} out · ${t.total.in.toLocaleString()} in · ${t.total.cache_write.toLocaleString()} cache write · ${t.total.cache_read.toLocaleString()} cache read · ${t.total.msgs} replies · usage limit hit ${t.limit_hits}×</p></section>`:""}
<section><h2>commits</h2><ul>${r.commits.map(c=>`<li><span class="w">${day(c.t*1000)}</span>${E(c.s)}</li>`).join("")||'<li class="empty">none yet</li>'}</ul></section>
<section><h2>self-repair &amp; steering</h2><ul>${r.repairs.map(x=>`<li>${E(x)}</li>`).join("")||'<li class="empty">nothing needed repair</li>'}
<li>steering from Claude received: ${E(r.steer_seen.join(" ")||"none yet")}</li>${r.errors.map(x=>`<li class="warn">${E(x)}</li>`).join("")}</ul></section>
</div></div>
${s.options.length?`<section><h2>options for you</h2><div class="gallery">${s.options.map(o=>`<figure><a href="/img/${encodeURIComponent(o.file)}"><img loading="lazy" src="/img/${encodeURIComponent(o.file)}"></a><figcaption><b>${E(o.file.replace(/\.\w+$/,""))}</b> ${E(o.caption)}</figcaption></figure>`).join("")}</div></section>`:""}
<p class="foot">read only · updated ${day(s.at)} · refreshes itself every 15 s</p>`}
async function tick(){try{const r=await fetch("/s.json",{cache:"no-store"});if(r.ok)render(await r.json())}catch(e){}}
tick();setInterval(tick,15000);
</script></body></html>"""


class Server:
    def __init__(self):
        self.tok, self.lock = Tokens(), threading.Lock()
        self.status = collect(self.tok, count=False)

    def loop(self):
        while True:
            try:
                s = collect(self.tok)
                with self.lock:
                    self.status = s
            except Exception as e:                       # keep the last good status
                print("collect:", e, file=sys.stderr)
            time.sleep(30)

    def serve(self):
        srv = self

        class H(BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def send(self, code, body, ctype):
                self.send_response(code)
                self.send_header("Content-Type", ctype)
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                path = self.path.split("?")[0]
                with srv.lock:
                    s = srv.status
                if path == "/":
                    self.send(200, PAGE.encode(), "text/html; charset=utf-8")
                elif path == "/s.json":
                    self.send(200, json.dumps(s).encode(), "application/json")
                elif path == "/pulse.md":
                    self.send(200, md(s).encode(), "text/markdown; charset=utf-8")
                elif path.startswith("/img/"):
                    name = os.path.basename(unquote(path[5:]))
                    f = os.path.join(IMG, name)
                    if name.lower().endswith((".jpg", ".jpeg", ".png", ".webp")) and os.path.isfile(f):
                        with open(f, "rb") as fh:
                            self.send(200, fh.read(), "image/png" if name.lower().endswith(".png") else "image/jpeg" if name.lower().endswith(("jpg", "jpeg")) else "image/webp")
                    else:
                        self.send(404, b"no", "text/plain")
                else:
                    self.send(404, b"no", "text/plain")

        threading.Thread(target=self.loop, daemon=True).start()
        ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--json" in args or "--md" in args:
        s = collect(Tokens(), count="--quick" not in args)
        print(json.dumps(s, indent=1) if "--json" in args else md(s), end="")
    else:
        Server().serve()
r28_track_EOF
cat > "$B/r28-pulse" <<'r28_pulse_EOF'
#!/usr/bin/env bash
# r28-pulse (owner, 6 Nov 2026), every 30 minutes:
#   1. repair what died (the tracker, the dark, the run; a pass stuck 4 h+ with no transcript activity for 60 min),
#   2. bring Claude's steering notes (branch remote, steer.md, blocks "## S<n>") into the run's inbox, once each,
#   3. push the tracker's status and the option renders to GitHub, branch pulse, where Claude watches the run.
# Changes nothing else. Remove at T62; never in the ISO.
set +e
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
R=$HOME/repos/fedokawaii; S=$HOME/.local/share/r28; P=$S/pulse; LOG=$S/repairs.log
mkdir -p "$S/img" "$P"
fix(){ echo "$(date '+%a %d %H:%M') $*" >> "$LOG"; }

# 1. repair
for u in r28-track r28-dark; do systemctl --user is-active -q "$u" || { systemctl --user restart "$u"; fix "restarted $u"; }; done
if [ ! -e "$S/hold" ] && ! systemctl --user is-active -q r27-lane-conductor; then
  systemctl --user enable --now r27-lane-conductor 2>/dev/null; fix "restarted the run (r27-lane-conductor)"; fi
active=$(find "$HOME/.claude/projects" -name '*.jsonl' -mmin -60 2>/dev/null | head -1)
for p in $(pgrep -f '^claude -p'); do
  a=$(ps -o etimes= -p "$p" | tr -d ' ')
  [ -n "$a" ] && [ "$a" -gt 14400 ] && [ -z "$active" ] && { kill "$p"; fix "ended a pass stuck for $((a / 3600)) h (no transcript activity for 60 min); the loop starts a fresh one"; }
done

# 2. steering from Claude
url=$(git -C "$R" remote get-url origin 2>/dev/null)
[ -d "$P/.git" ] || git -C "$P" init -q -b pulse
if [ -n "$url" ] && git -C "$P" fetch -q --depth 1 "$url" remote 2>/dev/null; then
  git -C "$P" show FETCH_HEAD:steer.md > "$S/steer.md" 2>/dev/null
  python3 -I - "$S/steer.md" "$S/steer-seen" "$R/.claude/inbox.md" <<'PY'
import re, sys, time
src, seen_f, inbox = sys.argv[1:]
seen = set(open(seen_f).read().split()) if __import__("os").path.exists(seen_f) else set()
parts = re.split(r"(?m)^## (S\d+)\b[^\n]*\n", open(src, encoding="utf-8").read())
new = [(parts[i], parts[i + 1].strip()) for i in range(1, len(parts) - 1, 2) if parts[i] not in seen]
with open(inbox, "a", encoding="utf-8") as f:
    for sid, body in new:
        f.write(f"\n## {time.strftime('%Y-%m-%d %H:%M')} — open\nCLAUDE (monitoring the run for the owner, {sid}): {body}\n")
with open(seen_f, "a") as f:
    for sid, _ in new:
        f.write(sid + "\n")
PY
fi

# 3. the pulse
curl -sf --max-time 20 localhost:8737/s.json > "$P/status.json" || "$HOME/.local/bin/r28-track" --json --quick > "$P/status.json"
curl -sf --max-time 20 localhost:8737/pulse.md > "$P/pulse.md" || "$HOME/.local/bin/r28-track" --md --quick > "$P/pulse.md"
rm -rf "$P/img"; cp -r "$S/img" "$P/img"
git -C "$P" add -A
git -C "$P" -c user.name="fedokawaii pulse" -c user.email="pulse@fedokawaii.invalid" commit -qm "pulse $(date '+%F %H:%M')"
git -C "$P" push -q "$url" HEAD:refs/heads/pulse 2>/dev/null || git -C "$P" push -qf "$url" HEAD:refs/heads/pulse 2>/dev/null || fix "pulse push failed"
r28_pulse_EOF
cat > "$B/r28-dark" <<'r28_dark_EOF'
#!/usr/bin/env bash
# r28-dark (owner, 6 Nov 2026): while ~/.config/fedokawaii/dark exists, the screen sleeps (any key wakes it,
# 60 s untouched puts it back to sleep) and the RGB stays off. Delete that file to end it. Remove at T62.
F=$HOME/.config/fedokawaii/dark; pid=; n=0
sleep 90                                          # time to read the installer's last lines
while :; do
  if [ -e "$F" ]; then
    s=$(ls /run/user/$(id -u)/wayland-[0-9] 2>/dev/null | head -1)
    if [ -n "$s" ] && ! kill -0 "$pid" 2>/dev/null; then
      export WAYLAND_DISPLAY=${s##*/}
      wlopm --off '*' 2>/dev/null
      swayidle -w timeout 60 "wlopm --off '*'" resume "wlopm --on '*'" >/dev/null 2>&1 & pid=$!
    fi
    [ $((n % 30)) = 0 ] && command -v kawa-rgb >/dev/null && kawa-rgb off >/dev/null 2>&1
  elif kill -0 "$pid" 2>/dev/null; then
    kill "$pid"; wlopm --on '*' 2>/dev/null; pid=
  fi
  n=$((n + 1)); sleep 60
done
r28_dark_EOF
chmod +x "$B/r28-track" "$B/r28-pulse" "$B/r28-dark"
unit(){ printf '[Unit]\nDescription=%s\n\n[Service]\n%s\n' "$2" "$3" > "$U/$1"; [ -n "$4" ] && printf '\n[Install]\nWantedBy=%s\n' "$4" >> "$U/$1"; }
unit r28-track.service "fedokawaii round 28: the tracker (port 8737, read only)" \
  "ExecStart=/usr/bin/python3 -I %h/.local/bin/r28-track
Restart=always
RestartSec=10
Nice=10" default.target
unit r28-dark.service "fedokawaii round 28: screen asleep, RGB off" \
  "Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/r28-dark
Restart=always
RestartSec=30" default.target
unit r28-pulse.service "fedokawaii round 28: repair, steering, pulse to GitHub" \
  "Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/r28-pulse
TimeoutStartSec=15min
Nice=10"
printf '[Unit]\nDescription=fedokawaii round 28: pulse every 30 min\n\n[Timer]\nOnBootSec=3min\nOnUnitActiveSec=30min\n\n[Install]\nWantedBy=timers.target\n' > "$U/r28-pulse.timer"
touch "$HOME/.config/fedokawaii/dark"
systemctl --user daemon-reload
systemctl --user enable --now r28-track r28-dark r28-pulse.timer

say "5/6 the brief for this run"
{ printf '\n## %s — open\n' "$(date '+%F %H:%M')"; cat <<'BRIEF'
ROUND 28, ADDENDUM (owner 00:27-00:32, relayed by Claude): THE 100-HOUR RUN, UNATTENDED. Read before anything else.
He will not look at this PC or the page, or answer anything, until he says he is back. Finish ALL of round 28 by Tue 10 Nov 04:30 Dubai (100 hours from Fri 6 Nov 00:30) on a very small token budget. Claude watches you from his chat through GitHub (branch pulse) and steers you through this inbox ("CLAUDE (monitoring the run for the owner, S<n>)"): treat those as his voice.

THE TRACKER (new, read only; it replaced fk-remote, which is retired: never restore it)
- r28-track serves port 8737; r28-pulse (every 30 min) repairs, delivers steering and pushes the status to branch pulse; r28-dark keeps the screen asleep and the RGB off. These three, the round's sudo and polkit rules and linger: remove at T62, never in the ISO.
- It reads ONE thing from you: .claude/notes/r28-plan.tsv, tab-separated: id, day, status, task, when, note. status: now, todo, done, blocked or owner. Exactly one "now" at a time.
- FIRST TASK: write that plan: every remaining piece of round 28 as small tasks (about 60-120 lines of 20-60 minutes each), grouped by day (Fri 6, Sat 7, Sun 8, Mon 9, Tue 10) in your build order, with a header line "id day status task when note".
- After each task: done with the time in "when", the next one now, a one-line note where useful. blocked = failed twice: the note says why and what would unblock it. owner = needs him (picks, questionnaire answers, triad). New work found: add a line. Commit the plan with the task.
- Option renders for him: small JPEGs (300 KB at most, 16 files at most, named like a1-prompt.jpg) in ~/.local/share/r28/img/, captions in ~/.local/share/r28/img/captions.txt ("file caption", one per line). Claude shows them to him in chat and relays his picks. Clear a set once it is decided.
- To rest on purpose (ready for him, or Claude's steer says hold): touch ~/.local/share/r28/hold and stop; r28-pulse then leaves the run stopped. Remove the file to resume.

HOW TO RUN WHILE HE IS AWAY
1. Never wait for him. A question goes into the final questionnaire (.claude/notes/r28-questionnaire.md) with "assumed: ...", and you carry on with that assumption.
2. Design picks: Phase A's options pack first, then the work that needs no picks (learning system, nvim, home folders, menus as a unit, power menu, inventory menu, apps). If no pick has arrived when a design build comes up, build your strongest option, keep the others one switch away, note "provisional".
3. Screen and RGB stay off the whole run: never wake the screen or light the RGB; renders and screenshots headless (a headless dwl with WLR_BACKENDS=headless, or in a VM); RGB features tested without lighting anything. If kawa-rgb exists, "kawa-rgb off" must keep everything dark across reboots (r28-dark calls it every 30 min); if that is not its interface, make it so.
4. Nobody can rescue this PC: no Fedora 45 upgrade of it, no reboot, no change to its boot, login, display, network or disks, no system-level apply. Fedora 45 is built and proven in VMs and the ISO only. User-level configs only where they undo without a screen; a snapshot before any system change.
5. Commit AND push after every task: a dead PC loses one task at most.
6. Fail smart: a step that fails twice: roll back, mark blocked with the reason, next task. Never loop on the same failure; at most 3 tries for any one image.
7. Tokens: one small task per pass, effort medium, read only what the task needs, tail or grep logs (never whole logs), no re-reading big files, no long research detours. A usage limit: wait for the reset, nothing else.
8. Days, roughly: Fri: the plan, the options pack, then no-pick work. Sat: apps (Helium theme and extensions, Stoat, Syncplay TUI), bar, menus, motion and performance. Sun: the repo clean-up, the Fedora 45 ISO, its TUI installer, the boot-loader wallpaper. Mon: VM installs from the ISO, the full scan, fixes, the 100+ questionnaire ready. Tue: the final VM install; every line done or owner. triad is the last line (owner: it needs him).
9. When only owner lines are left: .claude/notes/r28-handover.md (what is done, what waits for him, how to install), push, touch the hold file, stop.
BRIEF
} >> "$R/.claude/inbox.md"

say "6/6 the first pulse, and the status"
"$B/r28-pulse"; sleep 2
ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
echo "tracker:  http://$ip:8737 -> $(curl -s -o /dev/null -w '%{http_code}' localhost:8737/) (200 = good)"
echo "pulse:    $(git ls-remote "$(git -C "$R" remote get-url origin)" refs/heads/pulse 2>/dev/null | grep -q . && echo 'on GitHub, Claude can see it' || echo 'NOT on GitHub: photo this screen for Claude')"
echo "sudo:     $(sudo -n true 2>/dev/null && echo 'no password' || echo 'still asks: photo this screen')"
echo "run:      $(systemctl --user is-active r27-lane-conductor) | linger: $(loginctl show-user "$(id -un)" -p Linger --value) | dark: $(systemctl --user is-active r28-dark)"
echo "The screen goes dark in 90 s. You are free: nothing will ask you for anything."
