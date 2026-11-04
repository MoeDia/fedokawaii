---
id: rs-write-one
title: when you must write one
part: rust
chapter: 58
minutes: 7
needs: [rs-lifetime]
optional: no
---

## 58.2 when you must write one

A function that takes two references and returns one: which input does the result borrow from?
The compiler cannot tell from the signature, so it asks:

```rust
fn longer(a: &str, b: &str) -> &str {
    if a.len() >= b.len() { a } else { b }
}

fn main() {}
```

*The compiler says:*

```text
error[E0106]: missing lifetime specifier
 --> src/main.rs:1:32
  |
1 | fn longer(a: &str, b: &str) -> &str {
  |              ----     ----     ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value, but the signature does not say whether it is borrowed from `a` or `b`
help: consider introducing a named lifetime parameter
  |
1 | fn longer<'a>(a: &'a str, b: &'a str) -> &'a str {
  |          ++++     ++          ++          ++
```

The answer is a **lifetime parameter**, written `'a` (any name after an apostrophe). It names a
lifetime, like `T` names a type:

```rust
fn longer<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}

fn main() {
    let x = String::from("kyoto");
    let y = String::from("sharjah");
    println!("{}", longer(&x, &y));
}
```

*You should see:*

```text
sharjah
```

Read `<'a>(a: &'a str, b: &'a str) -> &'a str` as: *the result lives no longer than the shorter
of `a` and `b`.* It does not change how long anything lives; it **describes** the connection, so
the compiler can check each call:

```rust
fn longer<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}

fn main() {
    let x = String::from("kyoto");
    let result;
    {
        let y = String::from("sharjah");
        result = longer(&x, &y);
    }
    println!("{result}");
}
```

*The compiler says:*

```text
error[E0597]: `y` does not live long enough
  --> src/main.rs:10:29
   |
 9 |         let y = String::from("sharjah");
   |             - binding `y` declared here
10 |         result = longer(&x, &y);
   |                             ^^ borrowed value does not live long enough
11 |     }
   |     - `y` dropped here while still borrowed
12 |     println!("{result}");
   |                ------ borrow later used here
```
