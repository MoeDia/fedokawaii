---
id: git-log-diff
title: Reading what changed
part: 2
minutes: 15
needs: [git-commit]
---
## idea
git log lists the commits, newest first; with --oneline it is one line each. git diff shows what you changed since the last commit: a line with a minus was removed, a line with a plus was added. Read the diff before you commit, every time. It is the cheapest review you will ever get, and it catches the stray print you forgot.

## exercise
In ~/dojo/git/proj change hello.py so it prints hello instead of hi. Run git diff and read it. Then commit the change with the message "say hello in full". Run git log --oneline to see two commits.

## check
```check
run: git -C proj log --format=%s
in: git
expect: say hello in full
expect: add hello
```

## answer
The log shows the newest commit first.

```do
echo 'print("hello")' > proj/hello.py
git -C proj diff --stat
git -C proj commit -q -am "say hello in full"
```
