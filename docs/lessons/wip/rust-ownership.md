---
id: rust-ownership
title: Ownership, Rust's one big idea
part: 2
minutes: 20
needs: [rust-variables]
---
## idea
Every value in Rust has exactly one owner. Give it to someone else and the first owner no longer has it: it moved. When the owner goes out of scope, the value is freed, with no garbage collector running behind you.

```rust
let a = String::from("hi");
let b = a;
println!("{}", a);
```

That fails to compile: a moved into b. To keep both, copy on purpose with a.clone(). To let a function only look, lend the value with &: fn show(s: &String) reads it and gives it back. Small numbers like i32 are simply copied, so they never move. The compiler's complaints here are the lesson, not the obstacle.

## exercise
In ~/dojo/rs write own.rs. A function shout(s: &String) prints the text in capitals, using s.to_uppercase(). In main make let word = String::from("ember"), call shout(&word), then make let other = word.clone() and print other and word on one line with two holes.

## check
```check
run: rustc own.rs && ./own
in: rs
expect: EMBER
expect: ember ember
```

## answer
shout only borrows word, so main still owns it; the clone is a second, separate copy.

```file own.rs
fn shout(s: &String) {
    println!("{}", s.to_uppercase());
}

fn main() {
    let word = String::from("ember");
    shout(&word);
    let other = word.clone();
    println!("{} {}", other, word);
}
```
