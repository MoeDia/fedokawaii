---
id: git-why
title: Why history is kept
part: 2
minutes: 15
needs: [debugging-review]
---
## idea
Without history a file has only its latest version. Break it on Tuesday and Monday's working copy is gone. Git keeps every saved step, called a commit, so you can look back, compare and return. It lives in a hidden folder named .git inside your project. The command git init makes that folder, and from then on the project is a repository. Nothing is recorded yet: a new repository is an empty notebook.

## exercise
In ~/dojo/git make a folder named proj, enter it and run git init -b main. Then run git status and see what it says about the commits.

## check
```check
run: git -C proj status | sed -n 3p
in: git
expect: No commits yet
```

## answer
The status line says the repository exists and holds no commits yet.

```do
mkdir -p proj
git -C proj init -q -b main
```
