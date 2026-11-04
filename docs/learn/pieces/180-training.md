---
id: training
title: training, the context window
part: ai
chapter: 67
minutes: 3
needs: [tokens]
optional: no
---

## 67.3 training: where the knowledge comes from

A model is trained in stages:

| Stage | What happens | What it gives |
|---|---|---|
| pre-training | it reads a huge amount of text and learns to predict the next token | language, facts, code, reasoning patterns — everything it "knows" |
| fine-tuning | it is trained on examples of good answers to instructions | follows requests, answers as an assistant |
| reinforcement learning | its answers are scored (by people, by rules, by tests that pass or fail) and it is pushed towards the better ones | helpfulness, honesty, safety, and skill at tasks that can be checked, such as code |

> **Word — knowledge cutoff.** The date its training text ends. The model knows nothing after it
> unless you, or a tool such as web search, give it the newer facts.

Two consequences matter every day. The model knows the world as it was at its cutoff: a library's
newest version, this month's prices, today's news are past its edge. And it is best at what was
common in its training — popular languages, well-known libraries, standard patterns — and weaker
on rare ones, or on your own project's private conventions, until you show them to it.

## 67.4 the context window

> **Word — context window.** Everything the model can see at once: its instructions, the whole
> conversation, every file it read, every command's output. Measured in tokens.

The model has **no memory between conversations**. Everything it knows about your task is what is
in the context window right now. Every tool that seems to remember (Claude Code's `CLAUDE.md`,
chapter 70) works by putting text back into the context at the start.

The window is large — hundreds of thousands of tokens — but not free:

- **It fills up.** A long session of reading files and running commands can fill it. Then old
  parts are summarised or dropped, and details from the start can be lost.
- **More is not always better.** A model pays attention best to what is relevant. A context full
  of old attempts, unrelated files and long logs makes it slower, costlier and more likely to
  follow the wrong thread.
- **What is not there does not exist** for the model. If it is not in the context, it is guessing.

> **Checkpoint.** In one sentence each: what is a token, what is the context window, and why does
> a model not remember yesterday's conversation?
