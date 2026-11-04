---
id: py-agent-practice
title: practice
part: python
chapter: 47
minutes: 11
needs: [py-agent-loop]
optional: no
---

**47.1 ★ Watch the loop.** Print `reply.stop_reason` on every turn. How many turns does one
question take?

**47.2 ★★ A third tool.** `today_notes`: the lines under today's heading. Ask "what's on my
plate today?"

**47.3 ★★ Test without the network.** Test `search_notes` and `add_note` with a temporary file
(pytest's `tmp_path`, and `monkeypatch` for `NOTES` and `input`). Tools are ordinary functions:
test them as such.
