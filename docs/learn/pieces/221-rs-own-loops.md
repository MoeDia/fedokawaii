---
id: rs-own-loops
title: moves in loops and collections
part: rust
chapter: 51
minutes: 7
needs: [rs-own-functions]
optional: no
---

## 51.7 moves in loops and collections

A `for` loop over a `Vec` (chapter 55's list) takes ownership of it, item by item:

```rust
fn main() {
    let names = vec![String::from("Sara"), String::from("Omar")];
    for n in names {
        println!("{n}");
    }
    println!("{}", names.len());
}
```

*The compiler says:*

```text
error[E0382]: borrow of moved value: `names`
 --> src/main.rs:6:20
  |
2 |     let names = vec![String::from("Sara"), String::from("Omar")];
  |         ----- move occurs because `names` has type `Vec<String>`, which does not implement the `Copy` trait
3 |     for n in names {
  |              ----- `names` moved due to this implicit call to `.into_iter()`
...
6 |     println!("{}", names.len());
  |                    ^^^^^ value borrowed here after move
  |
note: `into_iter` takes ownership of the receiver `self`, which moves `names`
```

Loop over `&names` — borrowing it — and you keep it:

```rust
fn main() {
    let names = vec![String::from("Sara"), String::from("Omar")];
    for n in &names {
        println!("{n}");
    }
    println!("{}", names.len());
}
```

*You should see:*

```text
Sara
Omar
2
```

Taking a `String` *out* of a `Vec` by index would leave a hole, so Rust refuses; clone it, or
borrow it:

```rust
fn main() {
    let names = vec![String::from("Sara")];
    let first = names[0];
}
```

*The compiler says:*

```text
error[E0507]: cannot move out of index of `Vec<String>`
 --> src/main.rs:3:17
  |
3 |     let first = names[0];
  |                 ^^^^^^^^ move occurs because value has type `String`, which does not implement the `Copy` trait
  |
help: consider borrowing here
  |
3 |     let first = &names[0];
  |                 +
help: consider cloning the value if the performance cost is acceptable
  |
3 |     let first = names[0].clone();
  |                         ++++++++
```
