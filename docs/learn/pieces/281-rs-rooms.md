---
id: rs-rooms
title: modules: rooms in a program
part: rust
chapter: 59
minutes: 6
needs: [rs-lifetimes-practice]
optional: no
---

> **In this chapter**
>
> - split a program into modules and files; `pub`, `use`, `crate::`
> - a library and a binary in one package
> - crates from crates.io with `cargo add`
> - tests: unit tests, `assert_eq!`, `#[should_panic]`, tests in `tests/`, doc tests

## 59.1 modules: rooms in a program

A **module** groups related code under a name, and decides what the rest of the program may
see. Everything inside is **private** unless marked `pub`:

```rust
mod geometry {
    pub fn area(w: f64, h: f64) -> f64 {
        w * h
    }

    pub mod circle {
        pub fn area(r: f64) -> f64 {
            super::PI_ISH * r * r
        }
    }

    const PI_ISH: f64 = 3.14159;
}

use geometry::circle;

fn main() {
    println!("{}", geometry::area(2.0, 3.0));
    println!("{:.2}", circle::area(1.0));
}
```

*You should see:*

```text
6
3.14
```

| Write | Means |
|---|---|
| `mod name { … }` | a module |
| `pub` | visible outside its module |
| `geometry::area` | a path: the module, then the item |
| `use geometry::circle;` | bring a name in, to write `circle::area` |
| `super::` · `crate::` | the parent module · the top of this crate |

Private items stay private — the compiler enforces the boundary:

```rust
mod bank {
    pub struct Account {
        pub owner: String,
        balance: u64,
    }
}

fn main() {
    let a = bank::Account { owner: "Sara".into(), balance: 100 };
}
```

*The compiler says:*

```text
error[E0451]: field `balance` of struct `Account` is private
 --> src/main.rs:9:51
  |
9 |     let a = bank::Account { owner: "Sara".into(), balance: 100 };
  |                                                   ^^^^^^^ private field
```

*(a private field means only the module's own code can set it — so it can guarantee rules, like
"the balance only changes through `deposit`". Give the module a `pub fn new` that builds one)*
