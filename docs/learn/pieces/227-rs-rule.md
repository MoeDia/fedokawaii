---
id: rs-rule
title: the rule: many readers, or one writer
part: rust
chapter: 52
minutes: 6
needs: [rs-mut]
optional: no
---

## 52.3 the rule: many readers, or one writer

At any moment, a value can have **either** any number of `&` references, **or** exactly one
`&mut` — never both. Like a document: many people may read it at once, or one person may edit it,
but nobody reads while someone is halfway through an edit.

```rust
fn main() {
    let s = String::from("hi");
    let r1 = &s;
    let r2 = &s;
    println!("{r1} {r2}");
}
```

*You should see:*

```text
hi hi
```

```rust
fn main() {
    let mut s = String::from("hi");
    let r1 = &mut s;
    let r2 = &mut s;
    println!("{r1} {r2}");
}
```

*The compiler says:*

```text
error[E0499]: cannot borrow `s` as mutable more than once at a time
 --> src/main.rs:4:14
  |
3 |     let r1 = &mut s;
  |              ------ first mutable borrow occurs here
4 |     let r2 = &mut s;
  |              ^^^^^^ second mutable borrow occurs here
5 |     println!("{r1} {r2}");
  |                -- first borrow later used here
```

```rust
fn main() {
    let mut s = String::from("hi");
    let reader = &s;
    s.push('!');
    println!("{reader}");
}
```

*The compiler says:*

```text
error[E0502]: cannot borrow `s` as mutable because it is also borrowed as immutable
 --> src/main.rs:4:5
  |
3 |     let reader = &s;
  |                  -- immutable borrow occurs here
4 |     s.push('!');
  |     ^^^^^^^^^^^ mutable borrow occurs here
5 |     println!("{reader}");
  |                ------ immutable borrow later used here
```

This one rule is how Rust prevents a whole class of bugs — a list changed while someone loops
over it, two threads writing the same value (chapter 61) — at compile time.
