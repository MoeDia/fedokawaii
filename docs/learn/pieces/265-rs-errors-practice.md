---
id: rs-errors-practice
title: practice
part: rust
chapter: 56
minutes: 18
needs: [rs-counter]
optional: no
---

**56.1 ★ Parse or zero.** `fn to_num(s: &str) -> i32` returning the number, or 0 — with `unwrap_or`.

<!-- solution 56.1 -->
```rust
fn to_num(s: &str) -> i32 {
    s.trim().parse().unwrap_or(0)
}

fn main() {
    println!("{} {} {}", to_num("7"), to_num(" 12 "), to_num("x"));
}
```

*You should see:*

```text
7 12 0
```
<!-- /solution -->

**56.2 ★ Match a Result.** Parse `"3.14"` and `"pi"` as `f64` and print `ok VALUE` or `error MESSAGE` for each.

<!-- solution 56.2 -->
```rust
fn main() {
    for s in ["3.14", "pi"] {
        match s.parse::<f64>() {
            Ok(v) => println!("ok {v}"),
            Err(e) => println!("error {e}"),
        }
    }
}
```

*You should see:*

```text
ok 3.14
error invalid float literal
```
<!-- /solution -->

**56.3 ★ First with ?.** `fn double_str(s: &str) -> Result<i32, std::num::ParseIntError>` using `?`.

<!-- solution 56.3 -->
```rust
use std::num::ParseIntError;

fn double_str(s: &str) -> Result<i32, ParseIntError> {
    let n: i32 = s.parse()?;
    Ok(n * 2)
}

fn main() {
    println!("{:?} {}", double_str("21"), double_str("x").is_err());
}
```

*You should see:*

```text
Ok(42) true
```
<!-- /solution -->

**56.4 ★★ Sum of a list of strings.** `fn sum_all(v: &[&str]) -> Result<i32, String>` — collect into `Result<Vec<i32>, _>`, with the bad
value in the message.

<!-- solution 56.4 -->
```rust
fn sum_all(v: &[&str]) -> Result<i32, String> {
    let nums: Result<Vec<i32>, String> = v.iter().map(|s| s.parse::<i32>().map_err(|_| format!("not a number: {s}"))).collect();
    Ok(nums?.iter().sum())
}

fn main() {
    println!("{:?} {:?}", sum_all(&["1", "2", "3"]), sum_all(&["1", "two"]));
}
```

*You should see:*

```text
Ok(6) Err("not a number: two")
```
<!-- /solution -->

**56.5 ★★ Config line.** `fn parse_kv(line: &str) -> Option<(&str, &str)>` for `key = value` lines (with `split_once` and
`?`); `None` for anything else.

<!-- solution 56.5 -->
```rust
fn parse_kv(line: &str) -> Option<(&str, &str)> {
    let (k, v) = line.split_once('=')?;
    let (k, v) = (k.trim(), v.trim());
    if k.is_empty() { None } else { Some((k, v)) }
}

fn main() {
    for l in ["theme = dark", "font=12", "nonsense", "= x"] {
        println!("{l:?} → {:?}", parse_kv(l));
    }
}
```

*You should see:*

```text
"theme = dark" → Some(("theme", "dark"))
"font=12" → Some(("font", "12"))
"nonsense" → None
"= x" → None
```
<!-- /solution -->

**56.6 ★★ main returns Result.** Write a `main() -> Result<(), Box<dyn Error>>` that writes a file, reads it back and prints its
length — all with `?`.

<!-- solution 56.6 -->
```rust
use std::error::Error;
use std::fs;

fn main() -> Result<(), Box<dyn Error>> {
    fs::write("out.txt", "hello rust")?;
    let s = fs::read_to_string("out.txt")?;
    println!("{}", s.len());
    Ok(())
}
```

*You should see:*

```text
10
```
<!-- /solution -->
