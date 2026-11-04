---
id: rs-result
title: two kinds of failure; Result
part: rust
chapter: 56
minutes: 6
needs: [rs-collections-practice]
optional: no
---

> **In this chapter**
>
> - two kinds of failure: bugs (panic) and expected problems (`Result`)
> - `Result<T, E>`: `Ok` or `Err`, handled with `match`
> - the `?` operator: pass an error up in one character
> - your own error type; `Box<dyn Error>` for quick programs
> - the checkpoint for level 3: a word counter that never panics

## 56.1 two kinds of failure

| Kind | Example | In Rust |
|---|---|---|
| a **bug**: something that should be impossible | an index past the end, a broken promise | `panic!` — stop at once, with a message |
| an **expected problem** | a missing file, bad input, no network | `Result<T, E>` — a value saying what went wrong, for the caller to handle |

Python uses exceptions for both. Rust keeps them apart, and the type of every function shows
whether it can fail.

```rust
fn main() {
    let v = vec![1, 2, 3];
    let i = 7;
    println!("{}", v[i]);
}
```

*You should see:*

```text
thread 'main' (1) panicked at src/main.rs:4:21:
index out of bounds: the len is 3 but the index is 7
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

## 56.2 Result

`Result` is an enum, like `Option`:

```rust
enum Result<T, E> {
    Ok(T),    // it worked: here is the value
    Err(E),   // it failed: here is why
}
```

`"42".parse::<i32>()` returns a `Result`: the number, or a reason it is not one:

```rust
fn main() {
    for text in ["42", "4x2", ""] {
        match text.parse::<i32>() {
            Ok(n) => println!("{text:?} → {n}"),
            Err(e) => println!("{text:?} → error: {e}"),
        }
    }
}
```

*You should see:*

```text
"42" → 42
"4x2" → error: invalid digit found in string
"" → error: cannot parse integer from empty string
```

Reading a file returns a `Result` too — the file may not exist:

```rust
use std::fs;

fn main() {
    fs::write("hello.txt", "first line\nsecond line\n").unwrap();
    match fs::read_to_string("hello.txt") {
        Ok(text) => println!("{} lines", text.lines().count()),
        Err(e) => println!("could not read: {e}"),
    }
    match fs::read_to_string("missing.txt") {
        Ok(text) => println!("{} lines", text.lines().count()),
        Err(e) => println!("could not read: {e}"),
    }
}
```

*You should see:*

```text
2 lines
could not read: No such file or directory (os error 2)
```
