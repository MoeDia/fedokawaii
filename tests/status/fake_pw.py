#!/usr/bin/env python3
# fake PipeWire + WirePlumber, as wpctl and pw-dump see them: the machine is $FAKE_PW, a JSON
# file the tests change in place. What the real ones do was read off WirePlumber 0.5.18's
# wpctl and PipeWire's pw-dump (agent S, review13):
#   wpctl get-volume ID           "Volume: 0.40" · "Volume: 0.40 [MUTED]" (always "%.2f", any
#                                 locale); no such default: "Translate ID error…" on stderr,
#                                 nothing on stdout, status 0; no such node: status 0 as well
#   wpctl set-volume [-l L] ID V  V = 0.5 · 5%+ · 5%- · 0.05+; -l clamps the result to L —
#                                 also pulling a level above L down; never below 0
#   wpctl set-mute ID 0|1|toggle  wpctl set-default ID     (no such node: status 3)
#   PipeWire not running: "Could not connect to PipeWire", status 2 (pw-dump: 255)
#   pw-dump                       the nodes with their props, and the "default" metadata
# The default sink/source is the configured one while it exists, else the one with the
# highest priority.session (WirePlumber's choice; with no sound card that is "Share" — but
# with no microphone there is no default input at all).
# The state:
#   {"running": true, "configured": {"sink": NAME, "source": NAME},
#    "nodes": [{"id": 62, "class": "Audio/Sink", "name": …, "desc": …, "prio": 1009,
#               "vol": 0.4, "mute": false, "props": {…extra…}}, …]}
# Each call is logged to $FAKE_PW.log ("wpctl ARGS").
import fcntl
import json
import os
import sys

path = os.environ["FAKE_PW"]
prog = os.path.basename(sys.argv[0])
if prog not in ("wpctl", "pw-dump"):
    prog, sys.argv = sys.argv[1], sys.argv[1:]
args = sys.argv[1:]
lock = open(path + ".lock", "w")
fcntl.flock(lock, fcntl.LOCK_EX)
with open(path + ".log", "a") as lg:
    lg.write(prog + " " + " ".join(args) + "\n")
st = json.load(open(path))
nodes = st.get("nodes", [])


def save():
    json.dump(st, open(path + ".tmp", "w"), ensure_ascii=False)
    os.replace(path + ".tmp", path)


def default(kind):
    # (without a microphone there is no default input: "Share"'s monitor is never chosen —
    # while "Share" is, as an output, when it is the only one)
    classes = ("Audio/Sink",) if kind == "sink" else ("Audio/Source",)
    want = st.get("configured", {}).get(kind)
    cand = [n for n in nodes if n["class"] in classes]
    for n in cand:
        if n["name"] == want:
            return n
    cand.sort(key=lambda n: -n.get("prio", 0))
    return cand[0] if cand else None


if prog == "pw-dump":
    if not st.get("running", True):
        print("pw-dump: can't connect: Host is down", file=sys.stderr)
        sys.exit(255)
    out = [{"id": 0, "type": "PipeWire:Interface:Core", "info": {"props": {}}},
           {"id": 31, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "Dummy-Driver"}}}]
    for n in nodes:
        props = {"media.class": n["class"], "node.name": n["name"], "priority.session": n.get("prio", 0)}
        if n.get("desc") is not None:
            props["node.description"] = n["desc"]
        props.update(n.get("props", {}))
        out.append({"id": n["id"], "type": "PipeWire:Interface:Node", "version": 3,
                    "info": {"state": "suspended", "props": props}})
    md = []
    for kind, key in (("sink", "audio.sink"), ("source", "audio.source")):
        d = default(kind)
        if d:
            md.append({"subject": 0, "key": "default." + key, "type": "Spa:String:JSON", "value": {"name": d["name"]}})
        if st.get("configured", {}).get(kind):
            md.append({"subject": 0, "key": "default.configured." + key, "type": "Spa:String:JSON",
                       "value": {"name": st["configured"][kind]}})
    out.append({"id": 46, "type": "PipeWire:Interface:Metadata", "props": {"metadata.name": "settings"}, "metadata": []})
    out.append({"id": 47, "type": "PipeWire:Interface:Metadata", "props": {"metadata.name": "default"}, "metadata": md})
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    print()
    sys.exit(0)

# ── wpctl ─────────────────────────────────────────────────────────────────────
if not st.get("running", True):
    print("Could not connect to PipeWire", file=sys.stderr)
    sys.exit(2)
limit = None
if args[:1] in (["-l"], ["--limit"]) or (len(args) > 1 and args[1] in ("-l", "--limit")):
    i = args.index("-l") if "-l" in args else args.index("--limit")
    limit = float(args[i + 1])
    del args[i:i + 2]
cmd, rest = args[0], args[1:]


def resolve(ref):
    if ref in ("@DEFAULT_AUDIO_SINK@", "@DEFAULT_SINK@"):
        n = default("sink")
    elif ref in ("@DEFAULT_AUDIO_SOURCE@", "@DEFAULT_SOURCE@"):
        n = default("source")
    elif ref.isdigit():
        n = next((x for x in nodes if x["id"] == int(ref)), None)
        if n is None:
            print(f"Node '{ref}' not found", file=sys.stderr)
            return None
        return n
    else:
        print(f"Error: '{ref}' is not a valid number", file=sys.stderr)
        sys.exit(1)
    if n is None:
        print("Translate ID error: '-1' is not a valid ID (returned by default-nodes-api)\n", file=sys.stderr)
    return n


if cmd == "get-volume":
    n = resolve(rest[0])
    if n:
        print("Volume: %.2f%s" % (n["vol"], " [MUTED]" if n.get("mute") else ""))
    sys.exit(0)
if cmd == "set-volume":
    n = resolve(rest[0])
    if not n:
        sys.exit(3)
    v = rest[1]
    pct = v.endswith(("%+", "%-")) or v.endswith("%")
    num = float(v.rstrip("+-").rstrip("%"))
    step = num / 100 if pct else num
    if v.endswith("+"):
        new = n["vol"] + step
    elif v.endswith("-"):
        new = n["vol"] - step
    else:
        new = step
    if limit is not None and new > limit:
        new = limit
    n["vol"] = round(max(new, 0.0), 4)
    save()
    sys.exit(0)
if cmd == "set-mute":
    n = resolve(rest[0])
    if not n:
        sys.exit(3)
    n["mute"] = (not n.get("mute")) if rest[1] == "toggle" else rest[1] == "1"
    save()
    sys.exit(0)
if cmd == "set-default":
    n = resolve(rest[0])
    if not n:
        sys.exit(3)
    st.setdefault("configured", {})["sink" if n["class"] == "Audio/Sink" else "source"] = n["name"]
    save()
    sys.exit(0)
print(f"fake wpctl: {cmd} not modelled", file=sys.stderr)
sys.exit(1)
