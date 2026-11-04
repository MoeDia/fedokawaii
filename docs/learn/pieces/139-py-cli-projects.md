---
id: py-cli-projects
title: projects
part: python
chapter: 39
minutes: 180
needs: [py-cli-practice]
optional: yes
---

**39.5 ★★★ Subcommands.** A `calc` tool with subcommands `add A B`, `mul A B`, `sqrt X` (`add_subparsers`).

<!-- solution 39.5 -->
```python
import argparse, math

p = argparse.ArgumentParser(prog="calc")
sub = p.add_subparsers(dest="cmd", required=True)
for name in ("add", "mul"):
    s = sub.add_parser(name); s.add_argument("a", type=float); s.add_argument("b", type=float)
sub.add_parser("sqrt").add_argument("x", type=float)

for argv in (["add", "2", "3"], ["mul", "4", "2.5"], ["sqrt", "2"]):
    a = p.parse_args(argv)
    print({"add": lambda: a.a + a.b, "mul": lambda: a.a * a.b, "sqrt": lambda: math.sqrt(a.x)}[a.cmd]())
```

*You should see:*

```text
5.0
10.0
1.4142135623730951
```
<!-- /solution -->

**39.6 ★★★ Test the CLI.** Test `note.main` with pytest: `add` then `list --grep`, using `tmp_path`, `monkeypatch` and
`capsys` (pytest's fixture that captures printed output: `capsys.readouterr().out`).

<!-- solution 39.6 -->
```python
import note

def test_add_then_grep(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(note, "STORE", tmp_path / "n.jsonl")
    assert note.main(["add", "buy", "rice"]) == 0
    assert note.main(["add", "call", "Omar"]) == 0
    assert note.main(["list", "--grep", "RICE"]) == 0
    assert capsys.readouterr().out == "2026-10-21  buy rice\n"

def test_nothing_found(tmp_path, monkeypatch):
    monkeypatch.setattr(note, "STORE", tmp_path / "n.jsonl")
    assert note.main(["list"]) == 1
```
<!-- /solution -->

**39.7 ★★★★ wordfreq, finished.** Finish `wordfreq`: a `--ignore FILE` of words to skip, `--min-length`, output as JSON with
`--json`, tests for `top_words`, `uv tool install --editable .`, and run it on this book's
source (`docs/fedokawaii-learn.md` in the toolkit).

<!-- solution 39.7 -->
```python
import json, re
from collections import Counter

def top_words(text, n, ignore=frozenset(), min_length=1):
    words = [w for w in re.findall(r"[a-z']+", text.lower()) if w not in ignore and len(w) >= min_length]
    return Counter(words).most_common(n)

text = "The cat and the hat. The cat sat on the mat with the hat."
print(top_words(text, 3))
print(json.dumps(top_words(text, 2, ignore={"the"}, min_length=3)))
```

*You should see:*

```text
[('the', 5), ('cat', 2), ('hat', 2)]
[["cat", 2], ["hat", 2]]
```
<!-- /solution -->
