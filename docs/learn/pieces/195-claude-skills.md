---
id: claude-skills
title: skills and subagents
part: ai
chapter: 71
minutes: 4
needs: [claude-hooks]
optional: no
---

## 71.3 skills: your workflows, on demand

> **Word — skill.** A folder with a `SKILL.md`: instructions for one kind of job. The agent sees
> each skill's one-line description, and reads the whole file only when the job comes up — so a
> hundred skills cost almost nothing until used.

`.claude/skills/release/SKILL.md`:

```markdown
---
name: release
description: Cut a release of this project — version, changelog, tag
disable-model-invocation: true
---
Release version $ARGUMENTS:
1. `uv run pytest -q` must pass; stop and report if not
2. set the version in pyproject.toml
3. add a CHANGELOG.md section from `git log` since the last tag, in its style
4. commit "Release $ARGUMENTS", tag v$ARGUMENTS; do not push — show me the tag
```

`/release 1.4.0` runs it. `disable-model-invocation: true` means only you start it — right for
anything with side effects. Without that line, the agent uses the skill by itself whenever its
description fits — right for knowledge ("our API conventions", "how we write tests").

## 71.4 subagents: clean context for side jobs

> **Word — subagent.** A helper agent with its own, empty context. It does one job — research, a
> review — and hands back only a summary, so your main session stays uncluttered (67.4).

Just ask: *"use a subagent to find every place the date format is parsed, and report the file
and line of each"*. Or define one you will use often, in `.claude/agents/reviewer.md`:

```markdown
---
name: reviewer
description: Strict review of the current diff for bugs and missed requirements
tools: Read, Grep, Glob, Bash
---
You review the uncommitted diff (`git diff`) against PLAN.md. Report only what affects
correctness or a stated requirement, each with file, line and a suggested fix. No style notes.
```

A reviewer that never saw the work being made judges it on its own terms — the same reason a
second person reviews code (72.3).
