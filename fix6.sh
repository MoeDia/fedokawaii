#!/usr/bin/env bash
# fix 6 (4 Nov 21:30): put the design lanes first so they start now, allow 14 lanes (memory is healthy again).
set +e
R="$HOME/.config/fedokawaii/r27-lanes"
python3 - "$R" <<'EOF'
import sys, pathlib, os
p = pathlib.Path(sys.argv[1]); lines = p.read_text().splitlines()
order = ["updates","ink","pixels","appsui","integrate","asobi","iso","art","saver","fixer","learning",
         "chess","typing","torrents","f45","review","hardware","network","nvim","firealpaca","regress","system"]
head = [l for l in lines if l.startswith("# ")]
body = [l for l in lines if l.strip() and not l.startswith("# ")]
name = lambda l: l.lstrip("#").split("|", 1)[0]
rank = lambda l: order.index(name(l)) if name(l) in order else len(order)
tmp = p.with_suffix(".tmp"); tmp.write_text("\n".join(head + sorted(body, key=rank)) + "\n"); os.replace(tmp, p)
print("new order:", " ".join(name(l) + ("(paused)" if l.startswith("#") else "") for l in sorted(body, key=rank)))
EOF
sed -i 's/MAXL=[0-9]*/MAXL=14/' "$HOME/.local/bin/r27-conductor"
systemctl --user restart r27-lane-conductor
echo "conductor: $(systemctl --user is-active r27-lane-conductor) — ink, pixels and appsui start within a minute"
