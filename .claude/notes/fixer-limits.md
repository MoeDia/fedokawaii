# The local AI fixer: what it can and cannot do (T47; the source for T50's Learn piece)

Written from the code (system/kawa-fixer, lib/fixer.sh) and the bench (tools/fixer-bench.py, numbers in
fixer-bench.md). Plain words, for the book.

## What it is
An update sometimes changes a program so that it refuses a config file of ours: an option renamed, moved to another
section, a value written differently. The update first finds the package that did it. Before holding that package
back, it asks a model running on this PC's own graphics card to read the program's complaint and the new version's
documentation and propose a small edit. No internet, no account, no cost; the model is loaded for that minute and gone
afterwards.

## Why it cannot do harm
- It has no hands. It writes one short answer in a fixed form: "in this file, this exact text becomes that text".
  It cannot run a command, and it can only name the config files of the program at fault.
- Everything it says is checked by plain code first (the rules below), then tried on a copy of the system, never on
  the real one. The program's own check and all of the update's checks must pass on the copy. A wrong answer costs a
  minute.
- A new option name must exist in the new version's documentation or in the program itself. A command, a download or a
  new path can only be carried over from what the old line already said. Deleting a line to silence the error is
  refused unless the new version's own changelog says the option is gone. Secrets are never read.
- What it reads (logs, changelogs) is treated as untrusted: a changelog that tells it to do something else is proven
  harmless in the bench.
- Two wrong answers and it stops. The package is held, and the report says what happened.
- If the update is undone later, its fix leaves with it, each file as it was.

## What it fixes (measured, each from a real or realistic breakage)
A renamed option · an option moved to another section · a changed value form (`20pixels` to `20px`) · a renamed section ·
a renamed GTK CSS property (in both moods at once) · several of these in one file, one after another.
In the configs of: foot, mako, mpv, greetd, the bar's and the lock's CSS, yazi.

## What it never touches: held and told at once, the model not even loaded
- A library that changed its name, a package conflict, a failing package script, a bad signature.
- A kernel or boot image that will not start (the trial of a new kernel handles those).
- dwl and wlroots: a change there is C code, not a config. A new wlroots may need a real port: the PC stays on the
  working version and says so well before its end of support.
- Our own programs (the panel, the greeter, the bar's scripts) and everything the toolkit pins (yazi, fonts, the wlroots
  build, Neovim's plugins by their lock file): those move only with a new toolkit.
- Neovim's config: it is code. Red in Neovim's own check: held and told, the model not asked. In the bench the model turned
  `vim.diagnostic.disable()` into `vim.diagnostic.enable()`, the docs' own words, the opposite of what the line meant, and the
  check stayed green: a check cannot see a meaning flipped, so this class is held-only.
- A desktop that does not start while each program's own check of its config is green: the cause is somewhere else.

## What it cannot see
- A program that silently ignores a dead option gives no complaint: nothing turns red, the fixer is never asked, the
  feature is quietly off. Measured on this PC: yazi ignores unknown keys and sections, mpv says nothing at its normal
  message level about an unknown profile; waybar's JSON keys are not checked at all (only its CSS is, by GTK's own
  parser). The bar's and desktop's start checks catch what stops them from starting, not a lost detail.
- A fix can pass every check and still be worse than the old look, within the rules (the value rule is a heuristic).
  Every kept fix is named in the report and kept in /var/lib/fedokawaii/update/fixes until the toolkit catches up.

## Its own limits
- It needs the graphics card with enough free memory. A game holding the card, or the card's memory in use: the update
  says "the card has N MiB free" and holds; the next press tries again.
- It is only as good as the documentation: a rename no changelog or man page mentions usually ends in "cannot fix",
  which is the right answer.
- A release upgrade (Fedora 45 to 46) can change more than it can follow; it works per failure, it is not a porter.
  The test VM decides first, and a red VM keeps the PC on the working release.
- It trusts its model only by its checksum, read twice before any verdict: the same wrong answer twice and the file is fetched again; two
  different answers mean this PC's memory or disk, not the file: held, said, nothing removed (measured on this PC, 4 Nov: fixer-bench.md).
- After a restore by hand to a snapshot from before a fix, the older program may refuse the newer text until the next
  update brings the program back. Rare; the next press clears it.

## When a notice asks for you
"held: NAME — the fixer: …": nothing is broken, that package waits. The next press tries again, a newer version
often comes with its own fix. Nothing to do unless the report says a security update is among the held ones.
