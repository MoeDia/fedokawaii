---
id: py-agent-setup
title: set up, one question
part: python
chapter: 47
minutes: 3
needs: [py-cli-practice]
optional: no
---

> **In this chapter**
>
> - call Claude from Python
> - give it tools — functions of yours it may ask to run
> - the agent loop: ask, run the tool, give back the result, repeat
>
> An API key from `console.anthropic.com` (paid by use).

An **agent** is a model in a loop with tools. You describe the tools; the model decides when to
call one; your code runs it and hands back the result; the model carries on until it can
answer. Claude Code (chapter 21) is that loop with tools for files and the shell. Here you build
a small one, for your notes.

## 47.1 set up

Put the key in your secrets file — never in code — and open a new terminal:

```sh
# ~/.config/fedokawaii/secrets.sh (chmod 600)
export ANTHROPIC_API_KEY=sk-ant-…
```

```text
$ uv init notes-agent && cd notes-agent
$ uv add anthropic
```

## 47.2 one question

```python
import anthropic

client = anthropic.Anthropic()             # reads ANTHROPIC_API_KEY
reply = client.messages.create(
    model="claude-haiku-5-5",
    max_tokens=300,
    messages=[{"role": "user", "content": "Explain a gradient in two sentences."}],
)
print(reply.content[0].text)
```

*(Haiku is the quick, inexpensive model — right for learning. `claude-opus-5-5` is the most
capable)*
