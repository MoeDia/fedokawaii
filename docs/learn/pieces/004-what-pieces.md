---
id: what-pieces
title: files, paths, programs, variables
part: zero
chapter: 1
minutes: 7
needs: []
optional: no
---

Never typed a command? Start here. Three short chapters: what the pieces are called, your first
ten minutes in the terminal, and how to read the computer's complaints.

> **In this chapter**
>
> - what a file, a folder, a path, a program, a command and a variable are
> - one example of each, on this computer

Everything on a computer is one of a few kinds of thing. Once you can name them, every manual
becomes readable.

## 1.1 files and folders

A **file** is a named piece of stored data: a photo, a song, a letter, a program. A **folder**
(also called a *directory*) holds files and other folders. Your own files live in your
**home folder**, `/home/you` (with your user name instead of `you`), written `~` for short.

| Thing | Example on this desktop | What it is |
|---|---|---|
| a file | `~/notes/notes.md` | your notes: plain text |
| a folder | `~/captures` | where screenshots land |
| your home | `~` = `/home/you` | everything that is yours |
| the top of everything | `/` | every file on the computer sits somewhere below it |

## 1.2 paths

A **path** is a file's address: the folders you walk through to reach it, separated by `/`.

```text
/home/you/notes/notes.md
│ │    │   │     └── the file
│ │    │   └── a folder inside your home
│ │    └── your home folder
│ └── the folder that holds every home
└── the top: the root
```

> **Word — absolute and relative path.** An *absolute* path starts at `/` (or `~`) and works
> from anywhere. A *relative* path starts where you are: standing in your home, `notes/notes.md`
> means `/home/you/notes/notes.md`. `..` means "one folder up", `.` means "here".

## 1.3 programs and commands

A **program** is a file the computer can run. `nvim` (the editor), `mpv` (the video player)
and `ls` (lists files) are programs. A **command** is a line you type to run one, often with
**arguments** — words that tell it what to work on — and **options**, which start with `-`.

```text
ls  -l  ~/captures
│   │   └── an argument: which folder
│   └── an option: the long listing
└── the program
```

## 1.4 variables

A **variable** is a name that holds a value. The shell has some already: `$HOME` holds your
home's path, `$USER` your name. In programming (Part IV), variables are the first thing you
make.

```text
$ echo $HOME
/home/you
$ name=Kyoto
$ echo "I would like to visit $name"
I would like to visit Kyoto
```

*(no spaces around `=`: `name = Kyoto` would run a program called `name`)*

## 1.5 text, and why it matters here

Almost everything on this desktop is plain text: your notes, every setting, every script.
Plain text is readable by any program, searchable (`rg`, chapter 10), and its history can be
kept (git, chapter 14). That is why this book keeps returning to the terminal and the editor:
they are the two tools that work on everything.

### exercises

**1.1 ★ Name the parts.** In the command `cp -r ~/captures /run/media/stick`, which word is
the program, which the option, which the arguments?

*Expected:* the program is `cp` (copy), `-r` is an option (recursive: folders too), the two
paths are arguments: from where, to where.

**1.2 ★ Absolute or relative?** Which of these work from any folder: `~/notes`, `notes`,
`/etc/hosts`, `../books`?

*Expected:* `~/notes` and `/etc/hosts` (absolute); the other two depend on where you stand.
