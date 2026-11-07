---
id: git-branches
title: A branch as a safe experiment
part: 2
minutes: 15
needs: [git-log-diff]
---
## idea
A branch is a second line of history that starts from where you are. Try an idea on it and main stays untouched; if the idea is good, merge it in, and if it is bad, delete the branch and nothing is lost. git switch -c name makes a branch and moves onto it; git switch main goes back; git merge name brings its commits into the branch you stand on.

## exercise
In ~/dojo/git/proj run git switch -c shout. Change hello.py to print HELLO and commit it with the message "shout". Switch back to main, and merge shout into it.

## check
```check
run: git -C proj branch --show-current && cat proj/hello.py
in: git
expect: main
expect: print("HELLO")
```

## answer
On main again, the merged file holds the shouted line.

```do
git -C proj switch -q -c shout
echo 'print("HELLO")' > proj/hello.py
git -C proj commit -q -am "shout"
git -C proj switch -q main
git -C proj merge -q shout
```
