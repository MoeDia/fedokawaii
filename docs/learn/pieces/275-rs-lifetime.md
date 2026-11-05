---
id: rs-lifetime
title: what a lifetime is
part: rust
chapter: 58
minutes: 4
needs: [rs-borrow-practice, rs-traits-practice]
optional: no
---

> **In this chapter**
>
> - what a lifetime is: how long a reference stays valid
> - when you must write one (`'a`), and when the compiler works it out
> - structs that hold references
> - `'static`, and owning instead of borrowing
> - the checkpoint for level 4: a generic statistics library

## 58.1 what a lifetime is

Every reference is valid for some stretch of the program: from when it is made until the value
it points at is dropped or changed. That stretch is its **lifetime**. The compiler checks every
reference's lifetime fits inside its value's — that is how chapter 52's dangling references were
caught. Almost always it works lifetimes out by itself; this chapter is about the few times it
asks you.

```rust
fn main() {
    let r;
    {
        let x = 5;
        r = &x;
    }
    println!("{r}");
}
```

*The compiler says:*

```text
error[E0597]: `x` does not live long enough
 --> src/main.rs:5:13
  |
4 |         let x = 5;
  |             - binding `x` declared here
5 |         r = &x;
  |             ^^ borrowed value does not live long enough
6 |     }
  |     - `x` dropped here while still borrowed
7 |     println!("{r}");
  |                - borrow later used here
```

*(`x` is dropped at the inner `}`; `r` would point at nothing. The compiler draws it for you:
`x` does not live long enough)*
