---
id: rs-let
title: let, and shadowing
part: rust
chapter: 49
minutes: 8
needs: [rs-neovim]
optional: no
---

> **In this chapter**
>
> - `let`, and why variables cannot change unless you say `mut`
> - Rust's number types, `bool`, `char`, and text
> - functions with typed parameters and a returned value
> - expressions and statements: why the last line has no `;`

Rust is learnt in six levels, like Python in Part IV:

| Level | You learn | Chapters | Checkpoint |
|---|---|---|---|
| 1 | variables, types, functions, control flow | 49–50 | a number-guessing machine |
| 2 | ownership, borrowing, structs, enums | 51–54 | a bank with commands |
| 3 | collections, errors | 55–56 | a word counter that never panics |
| 4 | traits, generics, lifetimes | 57–58 | a generic statistics library |
| 5 | modules, tests, iterators, closures, threads | 59–61 | a parallel file scanner |
| 6 | a CLI, autograd, models in Rust, Rust in Python | 62–65 | your own crate on GitHub |

Every program here is complete: put it in `src/main.rs` of a `cargo new` project and
`cargo run` — or, for a quick try, save it as `main.rs` and run `rustc main.rs && ./main`. Each
was compiled with Rust 1.97 (edition 2024) and printed what is shown.

## 49.1 let: a name for a value

```rust
fn main() {
    let apples = 5;
    let price = 1.25;
    println!("{apples} apples cost {}", apples as f64 * price);
}
```

*You should see:*

```text
5 apples cost 6.25
```

`let` makes a variable. `println!` prints, filling each `{}` with the next value, and
`{apples}` with the variable of that name. (The `!` means `println` is a **macro**: code that
writes code. For now, just remember the `!`.)

**Variables cannot change** — unless you ask. This is Rust's first surprise:

```rust
fn main() {
    let count = 1;
    count = 2;
    println!("{count}");
}
```

*The compiler says:*

```text
error[E0384]: cannot assign twice to immutable variable `count`
 --> src/main.rs:3:5
  |
2 |     let count = 1;
  |         ----- first assignment to `count`
3 |     count = 2;
  |     ^^^^^^^^^ cannot assign twice to immutable variable
  |
help: consider making this binding mutable
  |
2 |     let mut count = 1;
  |         +++
```

The compiler says exactly what to do: add `mut` (*mutable*, changeable):

```rust
fn main() {
    let mut count = 1;
    println!("{count}");
    count = 2;
    count += 10;
    println!("{count}");
}
```

*You should see:*

```text
1
12
```

Why the default? Most values never need to change, and a value that cannot change cannot be
changed by mistake. When you see `mut`, you know to watch that name.

## 49.2 shadowing

A new `let` with the same name makes a **new** variable that hides the old one — even of a
different type. It is handy for converting a value step by step:

```rust
fn main() {
    let input = "42";
    let input: i32 = input.parse().unwrap();
    let input = input * 2;
    println!("{input}");
}
```

*You should see:*

```text
84
```

*(`.parse()` turns text into a number; `.unwrap()` means "I am sure it worked" — chapter 56
does this properly)*
