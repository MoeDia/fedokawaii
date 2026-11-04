---
id: rs-map-err
title: map_err; common mistakes
part: rust
chapter: 56
minutes: 5
needs: [rs-own-error]
optional: no
---

## 56.7 converting between errors: map_err

`map_err` turns one error into another, for example adding which line was wrong:

```rust
fn parse_line(n: usize, line: &str) -> Result<f64, String> {
    line.trim().parse::<f64>().map_err(|e| format!("line {n}: {line:?}: {e}"))
}

fn main() {
    let lines = ["3.5", "2", "abc"];
    let parsed: Result<Vec<f64>, String> = lines.iter().enumerate().map(|(i, l)| parse_line(i + 1, l)).collect();
    println!("{:?}", parsed);
    let good: Result<Vec<f64>, String> = ["1", "2"].iter().enumerate().map(|(i, l)| parse_line(i + 1, l)).collect();
    println!("{:?}", good);
}
```

*You should see:*

```text
Err("line 3: \"abc\": invalid float literal")
Ok([1.0, 2.0])
```

*(collecting `Result`s into `Result<Vec<_>, _>` stops at the first error — or gives all the values)*

## 56.8 common mistakes

**1. `?` in a function that returns nothing** — `the ? operator can only be used in a function
that returns Result or Option`. Change the return type (`main` too:
`-> Result<(), Box<dyn Error>>`).

```rust
fn main() {
    let n: i32 = "5".parse()?;
}
```

*The compiler says:*

```text
error[E0277]: the `?` operator can only be used in a function that returns `Result` or `Option` (or another type that implements `FromResidual`)
 --> src/main.rs:2:29
  |
1 | fn main() {
  | --------- this function should return `Result` or `Option` to accept `?`
2 |     let n: i32 = "5".parse()?;
  |                             ^ cannot use the `?` operator in a function that returns `()`
  |
help: consider adding return type
  |
1 ~ fn main() -> Result<(), Box<dyn std::error::Error>> {
2 |     let n: i32 = "5".parse()?;
3 +     Ok(())
  |
```

**2. `unwrap` on user input or files.** That is a panic waiting for a typo. Return the error,
or `match` it.

**3. Forgetting `Ok(...)`** around the final value of a function returning `Result`:
`expected Result<usize, …>, found usize`.
