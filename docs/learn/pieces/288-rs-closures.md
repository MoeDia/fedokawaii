---
id: rs-closures
title: closures
part: rust
chapter: 60
minutes: 5
needs: [rs-modules-practice]
optional: no
---

> **In this chapter**
>
> - closures: small functions that capture their surroundings
> - iterators: `map`, `filter`, `sum`, `collect` — Rust's comprehensions
> - laziness: nothing runs until something consumes it
> - writing your own iterator

## 60.1 closures

A **closure** is a function without a name, written `|args| body`. It can use the variables
around it — it **captures** them:

```rust
fn main() {
    let double = |x: i32| x * 2;
    let add = |a: i32, b: i32| a + b;
    println!("{} {}", double(21), add(2, 3));

    let rate = 0.05;
    let with_vat = |price: f64| price * (1.0 + rate);
    println!("{}", with_vat(200.0));

    let shout = |s: &str| {
        let up = s.to_uppercase();
        format!("{up}!")
    };
    println!("{}", shout("hello"));
}
```

*You should see:*

```text
42 5
210
HELLO!
```

*(types on closure parameters are usually optional: the compiler works them out from the first
use. Python's `lambda` is the same idea, limited to one expression)*

Closures that **change** what they capture must be `mut`; `move` makes a closure take ownership of
what it captures (needed for threads, chapter 61):

```rust
fn main() {
    let mut count = 0;
    let mut click = || count += 1;
    click();
    click();
    println!("{count}");

    let name = String::from("Sara");
    let greet = move || format!("hello {name}");
    println!("{}", greet());
}
```

*You should see:*

```text
2
hello Sara
```
