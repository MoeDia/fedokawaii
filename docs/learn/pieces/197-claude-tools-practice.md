---
id: claude-tools-practice
title: practice
part: ai
chapter: 71
minutes: 16
needs: [claude-more]
optional: no
---

**71.1 ★ Allow and deny.** Add the permission rules of 71.1 to `hello`'s `.claude/settings.json`.
Ask it to run the tests (no prompt), then to show you `.env` (refused).

*You should see:* the tests run without asking; reading `.env` denied.

<!-- solution 71.1 -->
`uv run pytest -q` with no prompt; *"show me .env"* gets a refusal naming the deny rule. To check
what is in force: `/permissions`.
<!-- /solution -->

**71.2 ★★ A formatting hook.** Add the hook of 71.2. Ask Claude Code to add a badly formatted
function. Open the file.

*You should see:* the function formatted although nobody asked for it.

<!-- solution 71.2 -->
```python
def total(xs):return sum( x for x in xs )
```

```python
def total(xs):
    return sum(x for x in xs)
```
<!-- /solution -->

**71.3 ★★ A guard.** Write `.claude/hooks/no-data.sh`, a `PreToolUse` hook that blocks any
`Edit` or `Write` under `data/` with exit code 2 and a reason. Ask it to edit a file in `data/`.

*You should see:* the edit blocked, and the agent explaining why in its own words.

<!-- solution 71.3 -->
```sh
#!/bin/bash
# no-data.sh — PreToolUse: no edits under data/
path=$(jq -r '.tool_input.file_path // empty')
case $path in
  */data/*|data/*) echo "data/ holds real data: never edited by the agent" >&2; exit 2 ;;
esac
exit 0
```

`chmod +x` it, and in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write",
        "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/no-data.sh" } ] }
    ]
  }
}
```

Asked to edit `data/2026.csv`, the agent reports the edit was blocked and why, and suggests
another way (a copy under `tests/`).
<!-- /solution -->

**71.4 ★★ Your first skill.** Write a skill `explain` that explains a file to a beginner, line
by line, then gives three questions to test understanding. Run `/explain src/app.py`.

*You should see:* the explanation and the three questions.

<!-- solution 71.4 -->
```markdown
---
name: explain
description: Explain a file to a beginner, line by line, then test understanding
disable-model-invocation: true
---
Explain $ARGUMENTS to someone who has done chapters 25–30 of a Python course:
1. one paragraph: what the file is for
2. each block in order: what it does and why, in plain words; name each Python idea used
3. three questions that check understanding, answers hidden until asked
Change nothing.
```
<!-- /solution -->
