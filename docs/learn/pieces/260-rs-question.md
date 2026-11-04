---
id: rs-question
title: shortcuts, the ? operator
part: rust
chapter: 56
minutes: 6
needs: [rs-result]
optional: no
---

## 56.3 shortcuts: unwrap, expect, unwrap_or

| Write | Does on `Err` | Use when |
|---|---|---|
| `match` / `if let` | whatever you write | always fine |
| `r.unwrap_or(d)` · `r.unwrap_or_default()` | gives `d` · zero, empty | a default makes sense |
| `r.expect("why")` | panics with your message | failure would be a bug: a file your program just wrote |
| `r.unwrap()` | panics | quick experiments, tests |
| `r?` | returns the error to the caller | inside a function that returns `Result` — the usual choice |

```rust
fn main() {
    let a: i32 = "12".parse().unwrap_or(0);
    let b: i32 = "twelve".parse().unwrap_or(0);
    let c: i32 = "".parse().unwrap_or_default();
    println!("{a} {b} {c}");
}
```

*You should see:*

```text
12 0 0
```

```rust
fn main() {
    let port: u16 = "70000".parse().expect("the port must be a number from 0 to 65535");
    println!("{port}");
}
```

*You should see:*

```text
thread 'main' (1) panicked at src/main.rs:2:37:
the port must be a number from 0 to 65535: ParseIntError { kind: PosOverflow }
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

## 56.4 the ? operator

Most functions cannot fix an error themselves; they pass it to their caller. `?` after a
`Result` does exactly that: if it is `Ok`, take the value and go on; if it is `Err`, **return**
the error from this function at once.

```rust
use std::fs;
use std::io;

fn count_lines(path: &str) -> Result<usize, io::Error> {
    let text = fs::read_to_string(path)?;
    Ok(text.lines().count())
}

fn main() {
    fs::write("notes.txt", "a\nb\nc\n").unwrap();
    println!("{:?}", count_lines("notes.txt"));
    match count_lines("nope.txt") {
        Ok(n) => println!("{n} lines"),
        Err(e) => println!("error: {e}"),
    }
}
```

*You should see:*

```text
Ok(3)
error: No such file or directory (os error 2)
```

Without `?`, the same function is a `match` per call:

```rust
fn count_lines(path: &str) -> Result<usize, io::Error> {
    let text = match fs::read_to_string(path) {
        Ok(t) => t,
        Err(e) => return Err(e),
    };
    Ok(text.lines().count())
}
```

`?` works on `Option` too, in a function that returns `Option` (chapter 54's `.ok()?`).
