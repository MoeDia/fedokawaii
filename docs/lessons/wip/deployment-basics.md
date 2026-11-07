---
id: deployment-basics
title: A program that leaves your machine
part: 2
minutes: 15
needs: [tests-pytest]
---
## idea
Deploying means the program runs somewhere that is not your editor: another folder, another computer, a timer at night. Three things make that work. A first line, the shebang, names the interpreter, like #!/usr/bin/env python3. The file's execute permission, set by chmod +x, lets you run it as ./hello.py without typing python3. And nothing in it may depend on your current folder or your own shell's variables, because the place it runs will have neither.

## exercise
In ~/dojo/deploy write hello.py with the shebang line and one print of: hello from anywhere. Run ./hello.py and read the error about permission. Fix it with chmod +x hello.py, then run it again.

## check
```check
run: ./hello.py
in: deploy
expect: hello from anywhere
```

## answer
With the shebang and the execute bit the system itself starts Python.

```file hello.py
#!/usr/bin/env python3
print("hello from anywhere")
```

```do
chmod +x hello.py
```
