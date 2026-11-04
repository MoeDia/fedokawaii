---
id: the-fixer
title: the local model: what it can and cannot do
part: desktop
chapter: 8
minutes: 4
needs: [notices]
optional: no
---

## 8.7 the local model: what it can and cannot do

An update sometimes makes a program refuse a config file of ours: an option renamed, moved to another
section, a value written differently. Before that package is held back, the update asks a language model
on this PC's own graphics card. It reads the program's complaint and the new version's documentation and
proposes a small edit. No internet, no account, no cost. The model is loaded for that minute and gone
afterwards, from the card and from memory.

It has no hands. Its answer is one short form, *in this file, this exact text becomes that text*, and plain
code decides what happens to it:

| the rule | what it stops |
|---|---|
| only the config files of the program at fault, never a secret | an answer touching anything else |
| a new option must exist in the new version's documentation or in the program itself | an invented option |
| a command, a download or a new path can only be carried over from what the old line said | a changelog steering it into running something |
| the option the changelog names as the replacement, if it names one | a neighbour that also passes the check |
| deleting a line only if the new version's changelog says the option is gone | silencing the error |
| tried on a copy of the system; the program's own check and every check of the update must pass | a fix that breaks something else |
| two wrong answers, then it stops | going round in circles |

What passes is kept and named in the report (*mended: foot.ini*). A fix stays in force through every later
update and is dropped by itself once fedokawaii has caught up. If the update is undone later, its fix leaves
with it, each file as it was: the older version would refuse the new text.

| it mends | it never touches: held and said at once, the model not even loaded |
|---|---|
| a renamed option, or section | a library that changed its name, a package conflict, a failing package script |
| an option moved to another section | a kernel or boot image (the trial of a new kernel handles those) |
| a value written differently | dwl and wlroots: that is C code, not a config |
| a renamed CSS property, in both moods at once | our own programs, and everything fedokawaii pins |
| several of these in one file | Neovim's config: it is code, and a check cannot see a meaning flipped |

> **Honestly.** It only sees what a program complains about. A program that silently ignores an option it no
> longer knows gives no complaint: yazi does, waybar's JSON keys are not checked at all. A fix can pass every
> check and still be slightly worse than what it replaced; that is why each one is named in the report. It needs
> the card's memory free: with a game holding the card, the package waits for the next press. And it works per
> failure: a release that changes something big is beyond it, as section 8.4 says.

*held: foot — the fixer: the docs do not say* in a report means nothing is broken and that package waits. The
next press tries again, and a newer version often brings its own fix. A move to a new Fedora goes the same way:
the fix is proven with the whole move in the copy, comes into force after the restart, and is said at the login.
