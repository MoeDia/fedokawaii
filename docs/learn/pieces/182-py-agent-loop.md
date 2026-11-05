---
id: py-agent-loop
title: the agent
part: python
chapter: 47
minutes: 10
needs: [py-agent-setup]
optional: no
---

## 47.3 the agent

```python
# agent.py — a notes assistant: Claude searches and adds to ~/Notes/notes.md through two tools
import datetime
from pathlib import Path

import anthropic

NOTES = Path.home() / "Notes" / "notes.md"
client = anthropic.Anthropic()

TOOLS = [
    {
        "name": "search_notes",
        "description": "Find lines in the user's notes that contain a word (case ignored). "
                       "Returns matching lines with their line numbers.",
        "input_schema": {
            "type": "object",
            "properties": {"word": {"type": "string", "description": "the word to look for"}},
            "required": ["word"],
        },
    },
    {
        "name": "add_note",
        "description": "Append one line to the user's notes. The user confirms it first.",
        "input_schema": {
            "type": "object",
            "properties": {"line": {"type": "string", "description": "the line to add"}},
            "required": ["line"],
        },
    },
]

```

The tools themselves are ordinary functions, and the loop calls them when Claude asks:

```python
def search_notes(word: str) -> str:
    hits = [f"{n}: {line}" for n, line in enumerate(NOTES.read_text(encoding="utf-8").splitlines(), 1)
            if word.lower() in line.lower()]
    return "\n".join(hits[:50]) or "no line contains that word"

def add_note(line: str) -> str:
    if input(f"  add to your notes: {line!r} — y/n? ").strip().lower() != "y":
        return "the user declined"
    with NOTES.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    return "added"

RUN = {"search_notes": search_notes, "add_note": add_note}

def agent(question: str) -> str:
    messages = [{"role": "user", "content": question}]
    system = f"You help the user with their notes. Today is {datetime.date.today():%A %d %B %Y}."
    while True:
        reply = client.messages.create(model="claude-haiku-5-5", max_tokens=1024,
                                       system=system, tools=TOOLS, messages=messages)
        if reply.stop_reason != "tool_use":
            return "".join(b.text for b in reply.content if b.type == "text")
        messages.append({"role": "assistant", "content": reply.content})
        results = []
        for block in reply.content:
            if block.type == "tool_use":
                print(f"  [{block.name} {block.input}]")
                results.append({"type": "tool_result", "tool_use_id": block.id,
                                "content": RUN[block.name](**block.input)})
        messages.append({"role": "user", "content": results})

if __name__ == "__main__":
    while (q := input("you › ")).strip():
        print(agent(q))
```

```text
$ uv run agent.py
you › what did I write about rice?
  [search_notes {'word': 'rice'}]
You noted "rice cooker: compare prices" (line 3) and "Rice, two kilos" (line 8).
you › remind me to buy it on Friday
  [add_note {'line': '- [ ] buy rice (Friday)'}]
  add to your notes: '- [ ] buy rice (Friday)' — y/n? y
Added "- [ ] buy rice (Friday)" to your notes.
you ›
```

*(for example; an empty line ends it)* Notice what you did *not* write: no rule for when to
search or which word to use. The model chose the tool and its argument from your question; your
code only did what it asked — and asked you before writing.
