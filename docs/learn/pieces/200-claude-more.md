---
id: claude-more
title: MCP, claude -p, many at once
part: ai
chapter: 71
minutes: 2
needs: [claude-skills]
optional: no
---

## 71.5 MCP: connecting other systems

> **Word — MCP (Model Context Protocol).** An open standard for giving agents tools from other
> systems: an issue tracker, a database, a design tool, your calendar.

`claude mcp add` connects one (each service documents its own line); `/mcp` lists what is
connected. Prefer a command-line tool when one exists (`gh` for GitHub): the agent already knows
it and it costs less context.

## 71.6 without the chat: `claude -p`

`-p` runs one request and prints the answer — for scripts, pipes and loops:

```text
$ journalctl -b -p err | claude -p "group these errors by cause, most serious first"
$ claude -p "list the public functions in src/ without a docstring" --output-format json
```

A loop over many files, each its own run, with only the tools it needs allowed:

```sh
for f in $(rg -l 'print\(' src/); do
  claude -p "In $f, replace print() debugging with the logging module. Run the tests." \
    --allowedTools "Edit,Bash(uv run pytest *)"
done
```

Try it on two files and read the diffs before you run it on two hundred.

## 71.7 many at once

Two agents editing the same folder trip over each other. Give each its own **git worktree** — a
second checkout of the same repository on its own branch:

```text
$ git worktree add ../hello-budgets -b budgets
$ cd ../hello-budgets && claude
```

herdr (chapter 21) shows them side by side. Patterns that work:

- **writer and reviewer**: one session writes; a fresh one reviews the diff; the first fixes.
- **tests first**: one session writes tests from the spec; another writes code until they pass.
- **explorers**: several read-only agents each investigate one question, then you decide.
