---
id: numbers
title: Numbers share work by a rule
part: 2
minutes: 14
needs: [variables]
standard: 2
---
## remember
```quiz
q: name = "Dia", then name = "Moe". What does print(name) write?
a: Moe
```

## example
Seven sweets, shared between two:

```python
sweets = 7
print(sweets // 2)
print(sweets % 2)
print(sweets / 2)
```
```output
3
1
3.5
```

Each gets 3 whole sweets, 1 is left over, and halving it exactly gives 3.5.

## idea
A number has no quotes. Python does arithmetic with signs: + adds, - takes away, * multiplies, / divides.

```term operator
a sign that does arithmetic, such as + or //
```
```term integer
a whole number, written without quotes or a point, such as 7
```
```term float
a number with a decimal point, such as 3.5
```

Two more signs share things out. // gives the whole part of a division. % gives what is left over. Seven shared between two is 3 whole, with 1 left over. So 7 // 2 is 3, and 7 % 2 is 1.

```term remainder
what is left over after sharing out the whole parts
```

A number in a variable works the same as a number typed in place.

## exercise
Warm-up: Predict first. Write down what 10 // 3 and 10 % 3 give. Then open a terminal with [[Super+Return]], type cd ~/dojo/py and press [[Enter]]. Check with python3 -c 'print(10 // 3, 10 % 3)' and [[Enter]]. The comma prints both answers on one line, a space between.

Real: In ~/dojo/py, type nvim sharing.py and press [[Enter]]. Press i to type. Put 17 in a variable called sweets, and 5 in a variable called friends. Print how many sweets each friend gets. On the next line, print how many are left over. Press [[Esc]], type :wq and press [[Enter]]. Run python3 sharing.py: you see 3, then 2.

Stretch: Predict first, again. If sweets were 20, what would the two lines be? Type nvim sharing.py and press [[Enter]]. Move to 17 with the arrow keys, press i, delete 17 and type 20. Press [[Esc]], type :wq and press [[Enter]]. Run it and compare. Then put 17 back the same way.

```hint
Each friend's share is the whole part. The leftover is the remainder.
```
```hint
Use the variables, not the numbers: sweets // friends, then sweets % friends.
```

## check
```check
run: python3 sharing.py
in: py
expect: 3
expect: 2
```

## answer
17 shared among 5 is 3 whole sweets each, and 2 are left over.

```file sharing.py
sweets = 17
friends = 5
print(sweets // friends)
print(sweets % friends)
```

## behind
Inside the computer, a number is kept in binary: only ones and zeros. 17 is 10001: one sixteen and one one. Python's integers grow as large as needed, so 2 multiplied by itself 100 times still fits. divmod does one division and gives both answers: (3, 2). The 0b in front of 10001 means binary.

```picture
<svg viewBox="0 0 400 120" role="img" aria-label="17 in binary: 10001, one sixteen and one one">
<text class="ink" x="8" y="40">17 =</text>
<g data-step="1"><text class="mark" x="80" y="40">1</text><text class="soft" x="76" y="70">16</text></g>
<g data-step="2"><text class="soft" x="130" y="40">0</text><text class="soft" x="130" y="70">8</text><text class="soft" x="180" y="40">0</text><text class="soft" x="180" y="70">4</text><text class="soft" x="230" y="40">0</text><text class="soft" x="230" y="70">2</text></g>
<g data-step="3"><text class="mark" x="280" y="40">1</text><text class="soft" x="280" y="70">1</text><text class="ink" x="8" y="104">16 + 1 = 17</text></g>
</svg>
```

Peek at both, in binary and as one division:

```peek
python3 -c 'print(bin(17), divmod(17, 5))'
```

## mistakes
- Quotes around a number: "7" + "2" is "72", two texts joined, not 9.
- One slash where two were meant: 17 / 5 is 3.4, not 3.

## quiz
```quiz
q: What does print(9 // 4) write?
a: 2
q: What does print(9 % 4) write?
a: 1
q: What does print(9 / 4) write?
a: 2.25
```

## next
Next: text in Python, and what you can do with it.

## checked
- The Python Tutorial, 3.14: https://docs.python.org/3.14/tutorial/introduction.html
- Built-in Types, 3.14: https://docs.python.org/3.14/library/stdtypes.html
