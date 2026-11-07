---
id: reading-docs
title: Reading documentation without fear
part: 2
minutes: 15
needs: [security-basics-2]
---
## idea
Documentation is written to be searched, not read top to bottom. Start with the one-line synopsis, then the list of options, and skip the rest until you need it. Every tool explains itself: command --help, man command, and for Python help(name) or python3 -m pydoc name. When a flag is unknown, search the help for a word you would use: sort, compact, quiet. Reading one page of official documentation beats ten guesses.

## exercise
In ~/dojo/docs make a.json holding {"b": 1, "a": 2}. Run python3 -m json.tool --help and look for the two options that sort the keys and remove all spaces. Use both on a.json.

## check
```check
run: python3 -m json.tool --sort-keys --compact a.json
in: docs
expect: {"a":2,"b":1}
```

## answer
The help names --sort-keys and --compact; together they print the keys in order with no spaces.

```do
printf '{"b": 1, "a": 2}\n' > a.json
```
