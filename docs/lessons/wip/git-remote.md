---
id: git-remote
title: Sharing a repository, with a key
part: 2
minutes: 15
needs: [git-branches]
---
## idea
A remote is another copy of the repository, usually on a server such as GitHub. git remote add origin URL names it; git push sends your commits, git pull fetches new ones. Over ssh the server knows you by a key pair, not a password: the private key stays on your machine and is never shared, the public key (the file ending .pub) goes to the server. Anyone with the private key is you, so it never goes in a repository, a chat or a note. Here the remote is a plain folder, which works the same way.

## exercise
In ~/dojo/git make a bare repository with git init -q --bare -b main remote.git. In proj run git remote add origin ../remote.git and git push origin main. Nothing was typed that could be a password.

## check
```check
run: git -C remote.git log --format=%s main | sed -n 1p
in: git
expect: shout
```

## answer
The newest commit now exists in the remote too.

```do
git init -q --bare -b main remote.git
git -C proj remote add origin ../remote.git
git -C proj push -q origin main
```
