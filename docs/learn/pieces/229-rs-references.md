---
id: rs-references
title: references: borrowing to look
part: rust
chapter: 52
minutes: 4
needs: [rs-own-practice]
optional: no
---

> **In this chapter**
>
> - references: look at a value without owning it (`&`)
> - change a value without owning it (`&mut`)
> - the borrowing rule: many readers or one writer
> - slices: borrow part of a string or an array

## 52.1 references: borrowing to look

A **reference** `&value` lets a function use a value while the caller keeps owning it. This is
called **borrowing**: like lending a book — the friend reads it and gives it back; it was always
yours.

```rust
fn length(s: &String) -> usize {
    s.len()
}

fn main() {
    let word = String::from("fedokawaii");
    let n = length(&word);
    println!("{word} has {n} letters");
}
```

*You should see:*

```text
fedokawaii has 10 letters
```

| Write | Means |
|---|---|
| `&word` | borrow `word`: make a reference to it |
| `s: &String` | `s` is a reference to a String, not a String |
| when `length` ends | the reference goes; `word` was never moved, nothing is dropped |

Chapter 51's clumsy "pass it in and hand it back" becomes simply:

```rust
fn shout(s: &str) {
    println!("{}!", s.to_uppercase());
}

fn main() {
    let word = String::from("hello");
    shout(&word);
    shout(&word);
    println!("{word} is still mine");
}
```

*You should see:*

```text
HELLO!
HELLO!
hello is still mine
```

*(a `&String` is accepted wherever a `&str` is asked, so functions that only read text take
`&str`: they then work with literals too — `shout("hi")`)*
