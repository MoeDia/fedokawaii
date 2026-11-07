---
id: security-basics-2
title: Keys need permissions
part: 2
minutes: 15
needs: [security-basics-1]
---
## idea
Every file has permissions for its owner, its group and everyone else, shown as three digits. ls -l prints them as letters. A new file is usually 644: the owner reads and writes, everyone else reads. A file that holds a secret should be 600, readable by you alone. chmod 600 FILE does it, and stat -c %a FILE tells the digits back. This is why the desktop keeps API keys in one file with mode 600. Use a made-up value for practice, never a real key.

## exercise
In ~/dojo/sec make secrets.sh holding one line: export DOJO_KEY=abc123, a made-up value. Look at its mode with stat -c %a secrets.sh, then make it readable by you alone with chmod.

## check
```check
run: stat -c %a secrets.sh
in: sec
expect: 600
```

## answer
Owner read and write, nobody else anything.

```do
printf 'export DOJO_KEY=abc123\n' > secrets.sh
chmod 600 secrets.sh
```
