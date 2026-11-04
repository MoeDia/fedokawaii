---
id: rs-generics
title: generics
part: rust
chapter: 57
minutes: 8
needs: [rs-std-traits]
optional: no
---

## 57.4 generics

A **generic** function works for many types. `T` is a placeholder for "some type"; a **trait
bound** (`T: PartialOrd`) says what `T` must be able to do — here, be compared:

```rust
fn largest<T: PartialOrd + Copy>(xs: &[T]) -> T {
    let mut best = xs[0];
    for &x in xs {
        if x > best {
            best = x;
        }
    }
    best
}

fn main() {
    println!("{}", largest(&[3, 9, 4]));
    println!("{}", largest(&[1.5, -2.0]));
    println!("{}", largest(&['k', 'y', 'o']));
}
```

*You should see:*

```text
9
1.5
y
```

Without the bound, the compiler refuses: it cannot know that any `T` has `>`:

```rust
fn largest<T>(xs: &[T]) -> &T {
    let mut best = &xs[0];
    for x in xs {
        if x > best {
            best = x;
        }
    }
    best
}

fn main() {}
```

*The compiler says:*

```text
error[E0369]: binary operation `>` cannot be applied to type `&T`
 --> src/main.rs:4:14
  |
4 |         if x > best {
  |            - ^ ---- &T
  |            |
  |            &T
  |
help: consider restricting type parameter `T` with trait `PartialOrd`
  |
1 | fn largest<T: std::cmp::PartialOrd>(xs: &[T]) -> &T {
  |             ++++++++++++++++++++++
```

Long bounds read better after a `where`:

```rust
use std::fmt::Display;

fn show_all<T>(items: &[T]) -> String
where
    T: Display,
{
    let parts: Vec<String> = items.iter().map(|i| format!("<{i}>")).collect();
    parts.join(" ")
}

fn main() {
    println!("{}", show_all(&[1, 2, 3]));
    println!("{}", show_all(&["a", "b"]));
}
```

*You should see:*

```text
<1> <2> <3>
<a> <b>
```
