---
id: rs-moving
title: moving, copying, cloning
part: rust
chapter: 51
minutes: 8
needs: [rs-scope]
optional: no
---

## 51.3 moving

A `String` keeps its text on the **heap** — memory that can grow — and the variable holds a
small record of where it is. When you assign it to another variable, Rust does not copy the text;
it **moves** ownership. The old name is no longer valid:

```rust
fn main() {
    let a = String::from("hello");
    let b = a;
    println!("{a}");
}
```

*The compiler says:*

```text
error[E0382]: borrow of moved value: `a`
 --> src/main.rs:4:16
  |
2 |     let a = String::from("hello");
  |         - move occurs because `a` has type `String`, which does not implement the `Copy` trait
3 |     let b = a;
  |             - value moved here
4 |     println!("{a}");
  |                ^ value borrowed here after move
  |
help: consider cloning the value if the performance cost is acceptable
  |
3 |     let b = a.clone();
  |              ++++++++
```

Why? If both `a` and `b` owned the same text, both would free it at the end — a crash in C. Rust
prevents it by having only one owner: after `let b = a;`, `b` owns it, and `a` is empty.

```text
let a = String::from("hello");         let b = a;

  a ──► [h e l l o]                      a   (moved: unusable)
                                         b ──► [h e l l o]
```

Using `b` is fine:

```rust
fn main() {
    let a = String::from("hello");
    let b = a;
    println!("{b}");
}
```

*You should see:*

```text
hello
```

## 51.4 copying: small simple values

Numbers, `bool`, `char` — and tuples and arrays of them — live entirely on the **stack**: they
are small and of fixed size, so copying is as cheap as moving. They are **Copy** types: `=` makes
a copy and both names stay valid:

```rust
fn main() {
    let x = 5;
    let y = x;
    let p = (1.5, true);
    let q = p;
    println!("{x} {y} {:?} {:?}", p, q);
}
```

*You should see:*

```text
5 5 (1.5, true) (1.5, true)
```

| Moves | Copies |
|---|---|
| `String`, `Vec`, `HashMap`, `Box` — anything that owns heap memory | `i32`, `f64`, `bool`, `char`, `usize` … |
| your structs, unless you derive `Copy` | tuples and arrays of Copy types |
| | `&T` — a borrow (chapter 52) |

## 51.5 cloning: a real copy, on purpose

When you do want two separate copies of heap data, ask for it with `.clone()`. It is explicit
because it costs time and memory — you see every place it happens:

```rust
fn main() {
    let a = String::from("hello");
    let mut b = a.clone();
    b.push_str(" world");
    println!("{a} | {b}");
}
```

*You should see:*

```text
hello | hello world
```
