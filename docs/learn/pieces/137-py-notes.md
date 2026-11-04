---
id: py-notes
title: checkpoint: notes, from the command line
part: python
chapter: 39
minutes: 40
needs: [py-package]
optional: no
---

## 39.8 checkpoint project — notes, from the command line

Level 5 in one tool: `note add TEXT`, `note list [--grep WORD]`, `note today`; notes in a JSON
lines file (one JSON object per line), read with a generator; tested with pytest; installed with
`uv tool install`. The core, without the packaging:

`note.py`:

```python
"""note — tiny notes from the command line."""
import argparse
import json
import sys
from collections.abc import Iterator
from datetime import date
from pathlib import Path

STORE = Path("notes.jsonl")

def read(path: Path) -> Iterator[dict]:
    if path.exists():
        with open(path, encoding="utf-8") as f:
            for line in f:
                yield json.loads(line)

def add(path: Path, text: str, day: str) -> None:
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps({"day": day, "text": text}) + "\n")

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="note")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add"); a.add_argument("text", nargs="+")
    ls = sub.add_parser("list"); ls.add_argument("--grep")
    sub.add_parser("today")
    args = p.parse_args(argv)
    today = "2026-10-21"  # date.today().isoformat() in your version
    if args.cmd == "add":
        add(STORE, " ".join(args.text), today)
        return 0
    notes = read(STORE)
    if args.cmd == "today":
        notes = (n for n in notes if n["day"] == today)
    elif args.grep:
        notes = (n for n in notes if args.grep.lower() in n["text"].lower())
    found = 0
    for found, n in enumerate(notes, 1):
        print(f"{n['day']}  {n['text']}")
    if not found:
        print("no notes", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

```text
$ uv run note.py add buy rice
$ uv run note.py add call Omar about Rust
$ uv run note.py list
2026-10-21  buy rice
2026-10-21  call Omar about Rust
$ uv run note.py list --grep rust
2026-10-21  call Omar about Rust
$ uv run note.py list --grep tea; echo "exit $?"
no notes
exit 1
```

*(`main(argv)` takes the arguments as a list, so a test can call `main(["add", "x"])` directly —
with `STORE` pointed into `tmp_path` by `monkeypatch.setattr(note, "STORE", tmp_path / "n.jsonl")`)*

> **Checkpoint.** Turn it into a package (`uv init --package note`), add `done N` and
> `--since DATE`, write pytest tests through `main([...])`, and `uv tool install --editable .`.
> When `note list` works from your home folder, level 5 is done.
