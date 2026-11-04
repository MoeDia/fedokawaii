---
id: glossary
title: the words, all of them
part: zero
chapter: 0
minutes: 8
needs: [the-plan]
optional: yes
---

| Word | Means | First in |
|---|---|---|
| absolute path | a path from `/` or `~`, the same from anywhere | 1.2 |
| agent | a model in a loop, calling tools you provide | 21, 47, 69 |
| argument | a word that tells a command what to work on; a value passed to a function | 1.3, 28.2 |
| array (NumPy) | many numbers of one type, worked on at once | 41.1 |
| assert | a check that stops the program if it is false | 28.6 |
| async, await | many waits overlapping in one program | 38.2 |
| attention | each position taking what it needs from earlier ones | 45 |
| autograd | the automatic computing of gradients | 44, 63 |
| borrow | using a Rust value without taking it over: `&` or `&mut` | 52.1 |
| branch | a line of commits of its own, for an experiment | 14 |
| broadcasting | NumPy stretching a smaller array to fit a larger one | 41.5 |
| class | your own kind of value: data and methods together | 34.1 |
| closure | a small nameless function that captures its surroundings | 60.1 |
| commit | a saved snapshot of a project, with a message | 14 |
| compositor | the program that draws and places the windows: dwl | 4 |
| comprehension | a loop that builds a list, dict or set in one line | 37.1 |
| container | a program with everything it needs, kept apart | 22 |
| context window | everything a model can see at once, counted in tokens | 67.4 |
| crate | a Rust library or program | 48, 59 |
| dataclass | a class whose `__init__`, `repr` and `==` are written for you | 34.5 |
| decorator | a function that wraps another: `@cache`, `@dataclass` | 37.7 |
| dictionary | a map from keys to values | 30.1 |
| embedding | a token turned into a learnt vector | 45 |
| enum | a Rust type whose value is one of several variants | 54.1 |
| epoch | one pass over all the training data | 44 |
| exception | Python stopping because a line cannot be done | 32.1 |
| f-string | text with values put in: `f"{x}"` | 25.5 |
| fine-tuning | teaching a trained model a little more | 46 |
| fixture | a value pytest makes for a test: `tmp_path` | 35.6 |
| function | a named piece of work, called with `()` | 28.1 |
| generator | a function that `yield`s values one at a time | 37.4 |
| generic | code for many types: `fn largest<T>` | 57.4 |
| gradient | how much the loss changes when a weight changes | 43 |
| hallucination | a confident answer that is wrong | 67.6 |
| hook | a command Claude Code always runs at a set moment | 71.2 |
| immutable | cannot be changed in place: strings, tuples; Rust's default | 26.4, 49.1 |
| iterator | something that gives values one at a time | 37.3, 60.3 |
| knowledge cutoff | the date a model's training text ends | 67.3 |
| lifetime | how long a Rust reference stays valid: `'a` | 58.1 |
| list | many values, in order, changeable | 29.1 |
| LoRA | fine-tuning small extra matrices instead of the whole model | 46 |
| loss | one number saying how wrong the model is | 43 |
| MCP | the open standard for giving agents tools from other systems | 71.5 |
| method | a function belonging to a value: `s.upper()` | 26.3 |
| module | a file of code you can `import` / `mod` | 33.1, 59.1 |
| move | handing a Rust value to a new owner | 51.3 |
| Mutex, Arc | a lock for one writer at a time; shared ownership across threads | 61.3 |
| Option | Rust's maybe-a-value: `Some(x)` or `None` | 54.5 |
| overfitting | memorising the training data instead of learning | 44 |
| ownership | Rust's rule: every value has one owner | 51.1 |
| package | installable code, from PyPI or crates.io | 33.4 |
| panic | Rust stopping the program on purpose: a bug was found | 49.3 |
| path | a file's address | 1.2 |
| pipe | `\|`: one command's output into the next | 9 |
| prompt | where the shell waits for your command; `>>>` for Python | 2, 25.1 |
| prompt injection | orders hidden in text an agent reads | 69.3 |
| REPL | Python's prompt: read, evaluate, print, loop | 25.1 |
| repository | a project folder git keeps the history of | 14 |
| Result | Rust's ok-or-error: `Ok(v)` or `Err(e)` | 56.2 |
| ROCm | AMD's computing stack, PyTorch's way to the card | 44 |
| sampling | choosing each next token from the model's probabilities | 67.2 |
| scope | where a name exists: a function's body, a `{ }` block | 28.5, 51.2 |
| set | values without repeats, with fast `in` | 30.7 |
| shell | the program that reads your commands: bash | 2 |
| skill | a folder of instructions an agent reads when the job comes up | 71.3 |
| slice | a part of a string, list or array: `s[1:4]`, `&s[1..4]` | 26.2, 52.6 |
| snapshot | a frozen copy of every file at a moment | 8 |
| string | text: `str` in Python; `String` and `&str` in Rust | 26.1, 49.4 |
| struct | a Rust type with named fields | 53.1 |
| subagent | a helper agent with its own, empty context | 71.4 |
| tensor | an array of any number of dimensions | 43 |
| test | a small program that checks your code: pytest, `cargo test` | 35.1, 59.4 |
| thread | a second line of work running at the same time | 61.1 |
| token | a piece of text a model reads as one number | 45, 67.1 |
| trait | a behaviour many Rust types can promise | 57.1 |
| transformer | the architecture of today's language models | 45 |
| tuple | a few values together, fixed | 29.6 |
| type | the kind of a value: `int`, `str`, `i32`, `String` | 25.4, 49.3 |
| type hint | `x: int` — what a name should hold, checked by mypy | 36.1 |
| variable | a name holding a value | 1.4, 25.3 |
| venv | a project's own Python and libraries | 24, 33.4 |
| workspace | one of nine desks of windows | 4 |
