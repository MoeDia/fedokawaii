---
id: rs-no-need
title: when you do not; structs that hold references
part: rust
chapter: 58
minutes: 7
needs: [rs-write-one]
optional: no
---

## 58.3 when you do not need one

The compiler fills lifetimes in by three rules (**elision**). The two that matter:

1. With exactly **one** reference coming in, a reference going out borrows from it:
   `fn first_word(s: &str) -> &str` needs no `'a`.
2. In a method with `&self`, a reference going out borrows from `self`.

```rust
struct Library {
    books: Vec<String>,
}

impl Library {
    fn first(&self) -> &str {
        &self.books[0]
    }
}

fn first_word(s: &str) -> &str {
    s.split(' ').next().unwrap_or("")
}

fn main() {
    let lib = Library { books: vec!["Dune".into(), "Emma".into()] };
    println!("{} {}", lib.first(), first_word("borrow checker"));
}
```

*You should see:*

```text
Dune borrow
```

So you write `'a` only when a function takes **two or more** references and returns one, or in
a struct that holds a reference.

## 58.4 structs that hold references

A struct can borrow instead of own — useful for a view into a big text without copying it. It
needs a lifetime parameter: the struct cannot outlive what it borrows.

```rust
#[derive(Debug)]
struct Highlight<'a> {
    text: &'a str,
    line: usize,
}

fn find<'a>(doc: &'a str, word: &str) -> Vec<Highlight<'a>> {
    let mut out = Vec::new();
    for (i, line) in doc.lines().enumerate() {
        if line.contains(word) {
            out.push(Highlight { text: line, line: i + 1 });
        }
    }
    out
}

fn main() {
    let doc = String::from("ownership\nborrowing rules\nlifetimes and borrowing");
    for h in find(&doc, "borrow") {
        println!("{}: {}", h.line, h.text);
    }
}
```

*You should see:*

```text
2: borrowing rules
3: lifetimes and borrowing
```

*(`find` takes two references but returns borrows only from `doc` — so only `doc` shares `'a`;
`word` needs none)*
