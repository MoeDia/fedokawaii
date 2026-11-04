---
id: rs-box-dyn
title: errors of different kinds
part: rust
chapter: 56
minutes: 5
needs: [rs-question]
optional: no
---

## 56.5 errors of different kinds: Box<dyn Error>

A function that can fail in two ways — reading a file (`io::Error`) and parsing a number
(`ParseIntError`) — needs one error type for both. The quick answer is
`Box<dyn std::error::Error>`: *any* error. `?` converts each into it for you:

```rust
use std::error::Error;
use std::fs;

fn sum_file(path: &str) -> Result<i64, Box<dyn Error>> {
    let text = fs::read_to_string(path)?;
    let mut total = 0;
    for line in text.lines() {
        total += line.trim().parse::<i64>()?;
    }
    Ok(total)
}

fn main() {
    fs::write("good.txt", "10\n20\n30\n").unwrap();
    fs::write("bad.txt", "10\nX\n").unwrap();
    for f in ["good.txt", "bad.txt", "none.txt"] {
        match sum_file(f) {
            Ok(t) => println!("{f}: {t}"),
            Err(e) => println!("{f}: error: {e}"),
        }
    }
}
```

*You should see:*

```text
good.txt: 60
bad.txt: error: invalid digit found in string
none.txt: error: No such file or directory (os error 2)
```

`main` itself may return a `Result`: an `Err` from `main` prints the error and exits with code 1.

```rust
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let n: i32 = "42".parse()?;
    println!("{n}");
    let m: i32 = "forty".parse()?;
    println!("{m}");
    Ok(())
}
```

*You should see:*

```text
42
Error: ParseIntError { kind: InvalidDigit }
```

*(the program printed 42, then stopped at the second `?` with `Error: …` and exit code 1. Only
`Ok(())` — "fine, nothing to return" — lets it finish)*
