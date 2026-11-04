---
id: git-moves
title: git, lazygit and gh
part: programs
chapter: 14
minutes: 14
needs: [nvim-moves]
optional: no
---

> **In this chapter**
>
> - commit, branch and undo with lazygit
> - put a project on GitHub with `gh`
> - see who changed what, and when

> **Word — commit.** A saved snapshot of a project, with a message saying why. **git** keeps
> every commit, so any version can come back. A **repository** is a project folder git looks
> after.

**Best at:** never losing work, and trying things without fear: commit, experiment, and if it
goes wrong, go back. **lazygit** is git with a screen: **Space g g** in neovim, or `lazygit` in
a terminal.

<!-- fig:app-lazygit | lazygit: the five panels on the left, the selected change on the right. -->

## 14.1 once

```text
$ git config --global user.name "Your Name"
$ git config --global user.email you@example.com
$ gh auth login
```

*(`gh` asks a few questions: GitHub.com, HTTPS, log in with a web browser)*

## 14.2 the moves in lazygit

| Keys | Does |
|---|---|
| **1** … **5** | the panels: status, files, branches, commits, stash |
| **Space** · **a** | stage a file · all files |
| **Enter** on a file | its lines: stage only some of them |
| **c** | commit (type the message, Enter) |
| **P** · **p** | push · pull |
| **n** (branches) · **Space** | a new branch · switch to one |
| **z** | undo the last git action |
| **s** | stash the changes away for a moment |
| **?** | every key of this panel |

## 14.3 GitHub: gh

lazygit does the work on your own machine; **gh** talks to GitHub.

| Command | Does |
|---|---|
| `gh repo create NAME --private --source . --push` | put this project on GitHub |
| `gh repo clone USER/NAME` | a copy of a project |
| `gh pr create` · `gh pr list` | a pull request · the open ones |

## 14.4 use cases

- every project in `~/repos` is a repository: the prompt shows its branch and changes
- an experiment on a branch: if it works, merge; if not, delete the branch
- `git log -p FILE`: why a line is the way it is

### exercises

**14.1 ★ First commit.** `mkcd ~/repos/hello`, `git init`, make `README.md` with one line,
commit it in lazygit (**a**, **c**).

*Expected:* lazygit's commits panel (**4**) shows one commit.

**14.2 ★★ Undo.** Change the README, commit; then undo that commit with **z** in lazygit.

**14.3 ★★ A branch.** Make a branch `idea`, commit a new file there, switch back to `main`.

*Expected:* the file disappears on `main` and returns on `idea`.
