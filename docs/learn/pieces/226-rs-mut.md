---
id: rs-mut
title: mutable references
part: rust
chapter: 52
minutes: 6
needs: [rs-references]
optional: no
---

## 52.2 mutable references: borrowing to change

A plain reference is read-only. To change the borrowed value, borrow it with `&mut` — and the
owner must be `mut` too:

```rust
fn add_bang(s: &mut String) {
    s.push('!');
}

fn main() {
    let mut word = String::from("hello");
    add_bang(&mut word);
    add_bang(&mut word);
    println!("{word}");
}
```

*You should see:*

```text
hello!!
```

```rust
fn add_bang(s: &String) {
    s.push('!');
}

fn main() {
    let word = String::from("hello");
    add_bang(&word);
}
```

*The compiler says:*

```text
error[E0596]: cannot borrow `*s` as mutable, as it is behind a `&` reference
 --> src/main.rs:2:5
  |
2 |     s.push('!');
  |     ^ `s` is a `&` reference, so it cannot be borrowed as mutable
  |
help: consider changing this to be a mutable reference
  |
1 | fn add_bang(s: &mut String) {
  |                 +++
```

For numbers, `*` reaches through the reference to the value (*dereferencing*):

```rust
fn bump(n: &mut i32) {
    *n += 1;
}

fn main() {
    let mut count = 0;
    bump(&mut count);
    bump(&mut count);
    println!("{count}");
}
```

*You should see:*

```text
2
```
