---
id: model-practice
title: practice
part: ai
chapter: 67
minutes: 12
needs: [hallucination]
optional: no
---

**67.1 ★ Same question, five times.** Run this five times and compare the answers:

```text
$ claude -p "Give me one name for a cat. Answer with the name only."
```

*You should see:* different names on different runs — sampling at work (67.2).

<!-- solution 67.1 -->
```text
$ for i in 1 2 3 4 5; do claude -p "Give me one name for a cat. Answer with the name only."; done
Miso
Mochi
Biscuit
Mochi
Pepper
```

Five runs, at least three names: each run samples a token from the same probabilities (67.2), so
the likely names come up most and the rest now and then.
<!-- /solution -->

**67.2 ★ Letters versus tokens.** Ask Claude Code (`claude -p`) how many times the letter `e`
occurs in `nevertheless`, then ask it to *write and run a Python line* that counts them.

*You should see:* the answer from code is always 4; the direct answer is usually right with
today's models, but the code is the one you can trust (67.1).

<!-- solution 67.2 -->
```text
$ claude -p "How many times does the letter e occur in 'nevertheless'? Answer with a number."
4
$ claude -p "Write and run one line of Python that counts the letter e in 'nevertheless'."
python3 -c "print('nevertheless'.count('e'))"  →  4
```

The model reads `nevertheless` as two or three tokens, not twelve letters; the code reads the
letters. Today's models usually get the direct question right, but only the code is *checked*.
<!-- /solution -->

**67.3 ★★ Find the edge.** Ask: *"What is the newest version of Python you know of, and what is
your knowledge cutoff?"* Then run `python3 --version` and compare.

*You should see:* the model names its cutoff; the machine may have something newer — the model
cannot know that unless you or a tool tell it (67.3).

<!-- solution 67.3 -->
cutoff and states the cutoff as a month and year. `python3 --version` on this desktop says
`Python 3.14.x`. If the model's newest is older, that is the edge of 67.3: it is not wrong about
its training, it is unaware of what came after. Give it the fact ("this machine runs Python 3.14")
and it will use it.
<!-- /solution -->

**67.4 ★★ Catch a hallucination.** Ask for *"the command-line option of `eza` that shows each
file's git status"* — then check with `eza --help | rg -i git`. Ask about an option that does
not exist too: *"what does `eza --rainbow-sort` do?"*

*You should see:* the real option (`--git`) confirmed by `--help`. For the invented one, a good
answer says it does not exist; if the model explains it confidently, you have caught one
(67.6).

<!-- solution 67.4 -->
```text
$ eza --help | rg -i git
  --git                      list each file's Git status, if tracked or ignored
  --git-repos                list root of git-tree status
  --no-git                   suppress Git status
```

`--git` is real. `--rainbow-sort` is not: `eza --rainbow-sort` answers `Unknown argument`.
A careful model says it does not know the option; a model that describes it is producing the
likely shape of an answer (67.6) — which is why you ran `--help`.
<!-- /solution -->
