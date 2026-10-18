#!/usr/bin/env python3
"""lsblk, as kawa-drives calls it, answered from a JSON file ($FAKE_DISKS): the tree
`lsblk -J -p -o …` prints. Also understands the narrower questions kawa-drives asks:
-J -o MOUNTPOINTS -- DEV · -nlpso NAME,TYPE -- DEV · -ndo SIZE,FSTYPE|TYPE -- DEV · -dno RM -- DEV."""
import json, os, sys

tree = json.load(open(os.environ["FAKE_DISKS"]))["blockdevices"]
args = sys.argv[1:]
dev = args[args.index("--") + 1] if "--" in args else None

def walk(nodes, parents=()):
    for n in nodes:
        yield n, parents
        yield from walk(n.get("children") or [], parents + (n,))

def find(name):
    for n, p in walk(tree):
        if n["name"] == name:
            return n, p
    return None, None

if dev is None:                                   # the whole tree
    print(json.dumps({"blockdevices": tree})); sys.exit(0)
node, parents = find(dev)
if node is None:
    print(f"lsblk: {dev}: not a block device", file=sys.stderr); sys.exit(32)
flags = "".join(a for a in args if a.startswith("-") and not a.startswith("--") and a != "-o")
if "-J" in args:                                  # -J -o MOUNTPOINTS -- DEV: its subtree
    def keep(n):
        return {"mountpoints": n.get("mountpoints", [None]), "children": [keep(c) for c in n.get("children") or []]}
    print(json.dumps({"blockdevices": [keep(node)]})); sys.exit(0)
if "s" in flags:                                  # inverse: the device, then what it sits on
    for n in (node,) + tuple(reversed(parents)):
        print(n["name"], n["type"])
    sys.exit(0)
# the column list follows "-o" or a cluster of short options ending in o (-ndo, -dno)
i = next(k for k, a in enumerate(args) if a == "-o" or (a.startswith("-") and not a.startswith("--") and a.endswith("o")))
fields = [c.strip().lower() for c in args[i + 1].split(",") if c.strip()]
def val(n, f):
    v = n.get(f)
    if f == "rm": return "1" if v else "0"
    return "" if v is None else str(v)
print(" ".join(val(node, f) for f in fields))
