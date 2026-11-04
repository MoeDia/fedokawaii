---
id: rs-scope
title: why ownership; scope
part: rust
chapter: 51
minutes: 8
needs: [rs-flow-practice]
optional: no
---

> **In this chapter**
>
> - the three rules of ownership, each with a tiny program
> - moving, copying and cloning
> - what happens when a value goes out of scope
> - ownership through functions: giving a value away and getting it back

This is the chapter that makes Rust *Rust*. Take it slowly: type every example, and read every
compiler message. Once ownership clicks, the rest of the language is easy — and you will see
why Rust programs do not crash.

## 51.1 why ownership

Every program must give memory back when it is done with it. Python does it with a *garbage
collector* that runs now and then and frees what nobody uses — convenient, but it costs time and
memory. C makes you free it by hand — fast, but forget once and the program leaks; free twice and
it crashes. Rust does neither. It follows three rules, checked **when you compile**, that say
exactly when each value is freed:

1. Every value has one **owner** — a variable.
2. There is only one owner at a time.
3. When the owner goes out of **scope**, the value is dropped (its memory freed).

Nothing runs to check these while the program runs: they cost nothing at all.

## 51.2 scope: where a variable lives

A variable lives from its `let` to the end of the `{ }` block it was made in. At that `}`, Rust
drops its value:

```rust
fn main() {
    let outer = String::from("outer");
    {
        let inner = String::from("inner");
        println!("{outer} {inner}");
    }
    println!("{outer}");
}
```

*You should see:*

```text
outer inner
outer
```

```rust
fn main() {
    {
        let inner = String::from("inner");
    }
    println!("{inner}");
}
```

*The compiler says:*

```text
error[E0425]: cannot find value `inner` in this scope
 --> src/main.rs:5:16
  |
5 |     println!("{inner}");
  |                ^^^^^
  |
help: the binding `inner` is available in a different scope in the same function
 --> src/main.rs:3:13
  |
3 |         let inner = String::from("inner");
  |             ^^^^^
```

You can watch a value being dropped. `Drop` is a trait (chapter 57) — code that runs at that
moment; here it just prints:

```rust
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("drop {}", self.0);
    }
}

fn main() {
    let _a = Noisy("a");
    {
        let _b = Noisy("b");
        println!("end of the inner block");
    }
    println!("end of main");
}
```

*You should see:*

```text
end of the inner block
drop b
end of main
drop a
```

*(values are dropped in reverse order of making: `b` at its `}`, then `a` at main's)*
