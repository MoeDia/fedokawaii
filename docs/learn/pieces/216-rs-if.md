---
id: rs-if
title: if and else
part: rust
chapter: 50
minutes: 5
needs: [rs-basics-practice]
optional: no
---

> **In this chapter**
>
> - `if` and `else` — as statements and as values
> - `loop`, `while` and `for`, with ranges
> - `break` with a value, labelled loops
> - the checkpoint for level 1: a number-guessing machine

## 50.1 if and else

Like Python's, without the colon; the condition needs no brackets, and must be a `bool` —
Rust never treats a number as true or false:

```rust
fn main() {
    let temp = 38;
    if temp > 35 {
        println!("too hot");
    } else if temp > 25 {
        println!("warm");
    } else {
        println!("cool");
    }
}
```

*You should see:*

```text
too hot
```

```rust
fn main() {
    let n = 3;
    if n {
        println!("non-zero");
    }
}
```

*The compiler says:*

```text
error[E0308]: mismatched types
 --> src/main.rs:3:8
  |
3 |     if n {
  |        ^ expected `bool`, found integer
```

`if` is an expression: it has a value, so it can sit on the right of `let`. Both branches must
give the same type:

```rust
fn main() {
    let age = 20;
    let group = if age >= 18 { "adult" } else { "minor" };
    let fee = if age < 12 { 0 } else { 25 };
    println!("{group} pays {fee}");
}
```

*You should see:*

```text
adult pays 25
```
