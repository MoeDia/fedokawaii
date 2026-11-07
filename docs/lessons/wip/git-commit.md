---
id: git-commit
title: A commit, one idea
part: 2
minutes: 15
needs: [git-why]
---
## idea
A commit is a saved step with a message. Two commands make it: git add chooses what goes in, git commit -m "message" saves it. Choosing first matters, because a commit should hold one idea: the message is one short sentence saying what the step does. Git also wants to know who you are; set it once per repository with git config user.name and git config user.email.

## exercise
In ~/dojo/git/proj set your name and email with git config (any values), write hello.py that prints hi, then git add hello.py and git commit -m "add hello". Check with git log --oneline.

## check
```check
run: git -C proj log --format=%s
in: git
expect: add hello
```

## answer
One file, one message, one commit.

```do
git -C proj config user.name "Dia"
git -C proj config user.email "dia@example.org"
echo 'print("hi")' > proj/hello.py
git -C proj add hello.py
git -C proj commit -q -m "add hello"
```
