---
id: why-python-rust
title: why Python and Rust
part: python
chapter: 23
minutes: 4
needs: []
optional: no
---

From your first line of Python to a language model you trained yourself, an AI fine-tuned on your
own notes, and an agent that uses tools — in six levels. Levels 1–5 (chapters 25–39) are the
language itself, one idea at a time, each with tiny examples, the mistakes everyone makes, graded
exercises and a checkpoint project. Level 6 (chapters 40–47) turns it to data and machine
learning. Every chapter builds on the one before; every step has something to run and something
to see.

> **In this chapter**
>
> - why these two languages, and not others
> - the plan of Parts IV and V

The AI world runs on two layers. On top, people describe models, data and experiments — in
**Python**: PyTorch, NumPy, Hugging Face, every research paper's code, the SDKs of Claude and the
other models. Underneath, the parts that must be fast and must never crash — tokenizers,
inference servers, data loaders, the tools that run AI on your own machine — are increasingly
written in **Rust**: Hugging Face's `tokenizers` and `safetensors`, the `candle` and `burn`
frameworks, `uv` (the Python tool you will use) and `ruff` are Rust.

| | Python | Rust |
|---|---|---|
| you write | what to do, briefly | what to do, and exactly who owns each piece of memory |
| speed | slow itself; fast through libraries written in C, C++ and Rust | as fast as C |
| mistakes found | when the line runs | before it runs: the compiler refuses unsafe code |
| for AI | the language of training, research, data, agents | the language of fast, safe tools and inference |
| learn it | in weeks | in months — and it teaches you how computers really work |

Together they cover the whole range: experiment in Python, make the slow part fast in Rust, call
it from Python (chapter 65). Other good choices exist — TypeScript for the web, C++ for CUDA
kernels, Mojo — but no other pair covers both research and production as well, today.

**The plan.** Chapter 24 sets up the daily routine once. Then each language is a course in six
levels, and each level ends with a checkpoint project that uses everything in it:

| Level | Python (Part IV) | Rust (Part V) |
|---|---|---|
| 1 | numbers, text, decisions, loops (25–27) | variables, types, functions, control flow (49–50) |
| 2 | functions, lists, dictionaries, sets (28–30) | ownership, borrowing, structs, enums (51–54) |
| 3 | files, errors, modules and uv (31–33) | collections, errors (55–56) |
| 4 | classes, pytest, type hints (34–36) | traits, generics, lifetimes (57–58) |
| 5 | generators, async, CLIs and packaging (37–39) | modules, tests, iterators, threads (59–61) |
| 6 | data, NumPy, a network from scratch, PyTorch, a transformer, fine-tuning, an agent (40–47) | a CLI with clap, your own autograd, candle and burn, PyO3 (62–65) |

Learn Python to level 3 first; then the two can go side by side — a Rust level after each Python
one is a good rhythm, because each language explains the other. Chapter 66 is a week-by-week
plan.

**How each lesson works.** A concept in plain words; three to six tiny programs, each with what
it prints under *You should see*; the mistakes beginners make, with the real error message; then
exercises from ★ to ★★★★, each with a worked solution. Type every example. Then
change one thing and predict what it will print before you run it — that habit, more than any
other, is what makes a programmer.
