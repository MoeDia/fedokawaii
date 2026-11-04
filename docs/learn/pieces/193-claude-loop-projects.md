---
id: claude-loop-projects
title: projects
part: ai
chapter: 70
minutes: 30
needs: [claude-md]
optional: yes
---

**70.4 ★★★ Your CLAUDE.md.** Write one for a project of yours in under fifteen lines. Test it: in a
fresh session ask "how do I run the tests here?" and "may I add the `requests` library?".

*You should see:* both answered from your file, word for word in spirit (70.5).

<!-- solution 70.4 -->
```markdown
# expenses — a command-line expense tracker

## Commands
- test: `uv run pytest -q` · one test: `uv run pytest -q -k NAME`
- types: `uv run mypy src` · style: `uv run ruff check . && uv run ruff format .`

## Rules
- standard library only; ask before adding any dependency
- money is integer cents, never float
- every command has a test in tests/test_cli.py

## Gotchas
- ~/.local/share/expenses holds my real data: tests use tmp_path
```

Asked *"how do I run the tests?"* it answers `uv run pytest -q`; asked *"may I add requests?"* it
says the project wants permission first, and asks you.
<!-- /solution -->
