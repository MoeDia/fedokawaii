---
id: model-projects
title: projects
part: ai
chapter: 67
minutes: 30
needs: [model-practice]
optional: yes
---

**67.5 ★★★ Watch the window fill.** In a new Claude Code session, run `/context`. Ask it to read
three large files of `~/dojo/fedokawaii`, then run `/context` again. Then `/clear` and look once
more.

*You should see:* the messages part of the context grow with every file, and go back to almost
nothing after `/clear` (67.4).

<!-- solution 67.5 -->
instructions, tools, memory files, messages — and how much is free. After three large files,
the messages part grows by roughly their size in tokens (a 40 KB script is around 10,000). After
`/clear` it drops back to the few hundred tokens of a fresh start: the files are gone from the
model's view entirely, which is the point of 67.4.
<!-- /solution -->
