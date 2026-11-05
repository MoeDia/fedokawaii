---
id: claude-hooks
title: settings and hooks
part: ai
chapter: 71
minutes: 4
needs: [claude-md]
optional: no
---

> **In this chapter**
>
> - permission rules: what it may always, never, or ask
> - hooks: the rules that are enforced, not requested
> - skills and subagents: your workflows, and helpers with clean context
> - MCP, headless runs, and many agents at once

`CLAUDE.md` asks. The tools in this chapter *make sure*, or *add abilities*.

## 71.1 settings and permission rules

Settings live in JSON files, from widest to narrowest: `~/.claude/settings.json` (you, everywhere),
`.claude/settings.json` (the project, in git) and `.claude/settings.local.json` (you, this project
only). Permission rules say what never needs asking, and what is never allowed:

```json
{
  "permissions": {
    "allow": ["Bash(uv run pytest *)", "Bash(git status)", "Bash(git diff *)"],
    "deny":  ["Read(./.env)", "Read(~/.config/fedokawaii/secrets.sh)", "Bash(git push *)"]
  }
}
```

`/permissions` shows and edits them. Allow what is safe and frequent — you stop clicking through
prompts without reading them; deny what must never happen.

## 71.2 hooks: rules that always hold

> **Word — hook.** A command Claude Code runs itself at a fixed moment — before a tool runs, after
> a file is edited, when it finishes. Unlike a line in `CLAUDE.md`, a hook is not a request: it
> always runs.

Format every Python file the moment it is edited (in `.claude/settings.json`):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command",
            "command": "jq -r '.tool_input.file_path' | rg '\\.py$' | xargs -r uv run ruff format" }
        ]
      }
    ]
  }
}
```

A hook gets the details of the event as JSON on its input. A `PreToolUse` hook that exits with
code 2 **blocks** the action, and what it printed to stderr goes back to the model as the reason —
so a script can forbid edits to `data/`, or any command containing `rm -rf`. Other useful moments:
`Stop` (when it finishes: run the tests, refuse to stop while they fail), `Notification` (it
needs you: `notify-send`), `SessionStart` (put today's context in). `/hooks` lists them.

Rule of thumb: if it must happen *every* time, it is a hook; if it is advice, it is `CLAUDE.md`.
