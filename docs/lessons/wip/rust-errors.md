---
id: rust-errors
title: Result and Option, errors as values
part: 2
minutes: 20
needs: [rust-ownership]
---
## idea
Rust has no exceptions. A thing that can fail returns a value that says so. Result is Ok(value) or Err(why); Option is Some(value) or None. You must look inside before you use the value, and match is how: it takes each case in turn and the compiler checks that you covered them all.

```rust
match "42".parse::<i32>() {
    Ok(n) => println!("{}", n),
    Err(_) => println!("not a number"),
}
```

Python's try let you forget the failure. Here forgetting does not compile. For a quick test script, .unwrap() takes the value or stops the program; never leave it where a failure is expected.

## exercise
In ~/dojo/rs write err.rs. A function half(text: &str) -> Option<i32> parses text as i32 and returns Some of half of it, or None when it is not a number. In main, for each of "10" and "ten", match half(...) and print half is 5 for Some, or none for None.

## check
```check
run: rustc err.rs && ./err
in: rs
expect: half is 5
expect: none
```

## answer
parse gives a Result; .ok() turns it into an Option, so one match covers both outcomes.

```file err.rs
fn half(text: &str) -> Option<i32> {
    let n: i32 = text.parse().ok()?;
    Some(n / 2)
}

fn main() {
    for t in ["10", "ten"] {
        match half(t) {
            Some(h) => println!("half is {}", h),
            None => println!("none"),
        }
    }
}
```
