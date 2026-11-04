---
id: rs-own-functions
title: ownership and functions
part: rust
chapter: 51
minutes: 7
needs: [rs-moving]
optional: no
---

## 51.6 ownership and functions

Passing a value to a function **moves** it into the function, just like `let b = a;`. When the
function ends, the value is dropped:

```rust
fn shout(s: String) {
    println!("{}!", s.to_uppercase());
}

fn main() {
    let word = String::from("hello");
    shout(word);
    shout(word);
}
```

*The compiler says:*

```text
error[E0382]: use of moved value: `word`
 --> src/main.rs:8:11
  |
6 |     let word = String::from("hello");
  |         ---- move occurs because `word` has type `String`, which does not implement the `Copy` trait
7 |     shout(word);
  |           ---- value moved here
8 |     shout(word);
  |           ^^^^ value used here after move
  |
note: consider changing this parameter type in function `shout` to borrow instead if owning the value isn't necessary
 --> src/main.rs:1:13
  |
1 | fn shout(s: String) {
  |    -----    ^^^^^^ this parameter takes ownership of the value
  |    |
  |    in this function
help: consider cloning the value if the performance cost is acceptable
  |
7 |     shout(word.clone());
  |               ++++++++
```

A function can give ownership back by returning the value:

```rust
fn add_bang(mut s: String) -> String {
    s.push('!');
    s
}

fn main() {
    let word = String::from("hello");
    let word = add_bang(word);
    let word = add_bang(word);
    println!("{word}");
}
```

*You should see:*

```text
hello!!
```

Passing in and handing back works, but is clumsy. Usually a function only needs to *look at*
a value, or change it, without owning it. That is **borrowing** — the next chapter.

Copy types are copied into functions, so the caller keeps its own:

```rust
fn double(n: i32) -> i32 {
    n * 2
}

fn main() {
    let n = 21;
    println!("{} {n}", double(n));
}
```

*You should see:*

```text
42 21
```
