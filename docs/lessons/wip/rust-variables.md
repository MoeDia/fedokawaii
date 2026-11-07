---
id: rust-variables
title: Variables and types in Rust
part: 2
minutes: 15
needs: [rust-first-steps]
---
## idea
let makes a variable. In Rust it cannot change unless you say let mut. Every value has a type, and the compiler knows it, mostly by itself: whole numbers are i32, decimals f64, text &str, true or false bool. You write the type only when it is not obvious, after a colon: let n: u8 = 7.

```rust
let mut score = 1;
score = score + 1;
let name = "Dia";
```

Python let a name hold anything. Rust fixes the type once, and refuses to add a number to text. That refusal is the compiler catching, before the program runs, the mistake Python would show at the worst moment.

## exercise
In ~/dojo/rs write vars.rs. In main make a mutable lives starting at 3 and a name "Dia". Subtract 1 from lives, then print Dia has 2 lives, using two holes. Compile and run it.

## check
```check
run: rustc vars.rs && ./vars
in: rs
expect: Dia has 2 lives
```

## answer
lives is mut because it changes; name is not, because it never does.

```file vars.rs
fn main() {
    let mut lives = 3;
    let name = "Dia";
    lives = lives - 1;
    println!("{} has {} lives", name, lives);
}
```
