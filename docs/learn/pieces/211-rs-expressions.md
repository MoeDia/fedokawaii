---
id: rs-expressions
title: functions, the missing semicolon
part: rust
chapter: 49
minutes: 7
needs: [rs-tuples]
optional: no
---

## 49.6 functions

```rust
fn area(width: f64, height: f64) -> f64 {
    width * height
}

fn greet(name: &str) {
    println!("hello, {name}!");
}

fn main() {
    greet("Sara");
    let a = area(3.0, 4.5);
    println!("{a}");
}
```

*You should see:*

```text
hello, Sara!
13.5
```

| Piece | Means |
|---|---|
| `fn area(…)` | a function named `area` |
| `width: f64` | every parameter has its type — always |
| `-> f64` | the type it gives back; none means it gives back nothing |
| `width * height` (no `;`) | the last expression is the value returned |

## 49.7 expressions and the missing semicolon

In Rust, almost everything is an **expression** — it has a value. A block `{ }` has the value
of its last line, *if that line has no semicolon*. A `;` turns an expression into a
**statement**, whose value is "nothing" — written `()`:

```rust
fn double(n: i32) -> i32 {
    n * 2
}

fn main() {
    let y = {
        let x = 3;
        x + 1
    };
    println!("{y} {}", double(y));
}
```

*You should see:*

```text
4 8
```

Add a semicolon to `n * 2` and the function returns nothing — and the compiler tells you why:

```rust
fn double(n: i32) -> i32 {
    n * 2;
}

fn main() {
    println!("{}", double(4));
}
```

*The compiler says:*

```text
error[E0308]: mismatched types
 --> src/main.rs:1:22
  |
1 | fn double(n: i32) -> i32 {
  |    ------            ^^^ expected `i32`, found `()`
  |    |
  |    implicitly returns `()` as its body has no tail or `return` expression
2 |     n * 2;
  |          - help: remove this semicolon to return this value
```

`return` exists too, for leaving early: `return 0;`. At the end of a function, the habit is the
plain last expression.
