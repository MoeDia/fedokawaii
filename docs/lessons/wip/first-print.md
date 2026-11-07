---
id: first-print
title: The first thing the machine says for you
part: 2
minutes: 14
standard: 2
---
## example
A file of two lines, run by python3:

```python
print("Konnichiwa")
print("I am learning Python")
```
```output
Konnichiwa
I am learning Python
```

Two orders, two lines, in the order they were written.

## idea
A program is a text file of orders. Python reads it from the top line down and does each order in turn.

```term program
a text file of orders the computer follows from the top line down
```

The smallest useful order is print. It writes a line on the screen. The words go between double quotes, so Python can tell your words from its own.

```term print
the Python order that writes what is between its brackets on the screen, then a new line
```
```term string
text between quotes, kept by Python exactly as you wrote it
```

A Python file ends in .py, and python3 runs it. Nothing happens while you write. It all happens when you run the file.

```term python3
the program that reads a .py file and does its orders
```

## exercise
Warm-up: Open a terminal with [[Super+Return]]. Type mkdir -p ~/dojo/py and press [[Enter]]. Then type cd ~/dojo/py and press [[Enter]]. This folder is where your Python practice lives.

```term terminal
a window where you type orders for the computer, one line at a time
```

Real: Type nvim hello.py and press [[Enter]]. Press i, so your keys type text. Write one print line that says Konnichiwa. Press [[Esc]], type :wq and press [[Enter]]: the file is saved and nvim closes. Now type python3 hello.py and press [[Enter]]. You see Konnichiwa.

Stretch: Predict first, then run. Make a second file, two.py, the same way. Give it two print lines: Ohayou on the first, Konnichiwa on the second. Before you run it, write down which word you expect on top. Then run python3 two.py and compare.

```hint
The word goes inside the round brackets, between double quotes.
```
```hint
Start with print, then an opening bracket, a quote, the word, a quote, a closing bracket.
```

## check
```check
run: python3 hello.py
in: py
expect: Konnichiwa
```

## answer
The file holds one order and nothing else, so its output is exactly one line.

```file hello.py
print("Konnichiwa")
```

## behind
python3 first reads your whole file. It turns each line into small steps called bytecode. Then it does the steps, one by one. The steps for print send your text to the terminal, followed by a new line. The terminal draws the letters.

```term bytecode
the small steps Python turns your file into before it does them
```

```picture
<svg viewBox="0 0 400 120" role="img" aria-label="hello.py goes to python3, becomes bytecode, and the terminal shows Konnichiwa">
<g data-step="1"><rect class="line" x="8" y="40" width="80" height="40" rx="4"/><text class="ink" x="48" y="65" text-anchor="middle">hello.py</text></g>
<g data-step="2"><path class="soft" d="M90 60h28"/><rect class="line" x="120" y="40" width="80" height="40" rx="4"/><text class="ink" x="160" y="65" text-anchor="middle">python3</text></g>
<g data-step="3"><path class="soft" d="M202 60h28"/><rect class="line" x="232" y="40" width="72" height="40" rx="4"/><text class="soft" x="268" y="65" text-anchor="middle">bytecode</text></g>
<g data-step="4"><path class="soft" d="M306 60h12"/><text class="mark" x="320" y="65">Konnichiwa</text></g>
</svg>
```

See the steps for yourself, from inside ~/dojo/py:

```peek
python3 -m dis hello.py
```

LOAD_CONST holds your word. CALL is print doing its work.

## mistakes
- No quotes: print(Konnichiwa) stops with a NameError, because Python looks for a name.
- A capital P: Print is not print, and Python stops.
- The wrong file: python3 hello.py runs hello.py, not two.py. Type the name of the file you mean.

## quiz
```quiz
q: What does print("Hi") write?
a: Hi
q: Which program runs hello.py?
a: python3
q: A file has two print lines. Which one comes out first?
a: the top one
```

## next
Next: a variable, a name that holds a value.

## checked
- The Python Tutorial, 3.14: https://docs.python.org/3.14/tutorial/introduction.html
- Using the Python Interpreter, 3.14: https://docs.python.org/3.14/tutorial/interpreter.html
- dis, 3.14: https://docs.python.org/3.14/library/dis.html
