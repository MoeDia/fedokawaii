---
id: claude-md
title: CLAUDE.md
part: ai
chapter: 70
minutes: 14
needs: [claude-steps]
optional: no
---

## 70.5 CLAUDE.md: what every session should know

Every session starts empty (67.4). `CLAUDE.md` is read at the start of each one, so it is where
your project's lasting knowledge lives. `/init` writes a first version; you keep it short and
true.

| File | For |
|---|---|
| `CLAUDE.md` in the project (in git) | the project: commands, conventions, gotchas — shared with everyone |
| `CLAUDE.local.md` in the project (in `.gitignore`) | your own notes for this project |
| `~/.claude/CLAUDE.md` | you, in every project: how you like to work |

A good one is short — a list of things the agent could not guess:

```markdown
# hello

## Commands
- test: `uv run pytest -q` · one file: `uv run pytest -q tests/test_x.py`
- lint and types: `uv run ruff check . && uv run mypy src`

## Conventions
- Python 3.14, standard library first; ask before adding a dependency
- every public function has a type-hinted signature and a test
- messages to the user in plain English, no jargon

## Gotchas
- `data/` holds real data: tests use tmp_path, never data/
```

For each line ask: *would the agent make a mistake without it?* If not, cut it. A long file gets
skimmed — by models as by people — and the rule that matters drowns. `@docs/style.md` on a line
of its own brings another file in. Claude Code also keeps its own notes as it learns your
preferences (`/memory` shows them).

### exercises

**70.1 ★ The modes.** Start `claude` in `~/repos/hello`, press **Shift+Tab** until each mode has
shown once, and ask in plan mode for a change. Confirm nothing changed with `git status`.

*You should see:* a plan, and `nothing to commit, working tree clean`.

<!-- solution 70.1 -->
proceed; nothing is written. `git status` afterwards:

```text
$ git status
On branch main
nothing to commit, working tree clean
```
<!-- /solution -->

**70.2 ★★ The full loop.** Add a feature to `hello` through all four steps of 70.3. Keep the plan
in `PLAN.md`.

*You should see:* a commit whose diff you read before it was made, with passing tests.

<!-- solution 70.2 -->
```markdown
# --ja
1. test: `hello --ja Ana` prints "こんにちは、Ana"  (tests/test_cli.py)
2. cli.py: add the option; greet() takes lang="en"
3. README: one line under Usage
check: uv run pytest -q
```

and a commit, after you read `git diff`, like `Hello: --ja says it in Japanese`.
<!-- /solution -->

**70.3 ★★ Rewind.** Ask for a change, let it finish, then **Esc Esc** and restore the code to
before it. Check with `git diff`.

*You should see:* an empty diff.

<!-- solution 70.3 -->
code*:

```text
$ git diff
$
```

Empty: the files are as they were before that turn.
<!-- /solution -->
