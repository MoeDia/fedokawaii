---
id: rs-flow-mistakes
title: common mistakes
part: rust
chapter: 50
minutes: 4
needs: [rs-labels]
optional: no
---

## 50.6 common mistakes

**1. A number as a condition** — `expected bool, found integer`. Compare it: `if n != 0`.

**2. Branches of different types** in an `if` used as a value:

```rust
fn main() {
    let x = 5;
    let label = if x > 3 { "big" } else { 0 };
}
```

*The compiler says:*

```text
error[E0308]: `if` and `else` have incompatible types
 --> src/main.rs:3:43
  |
3 |     let label = if x > 3 { "big" } else { 0 };
  |                            -----          ^ expected `&str`, found integer
  |                            |
  |                            expected because of this
```

**3. Off by one with ranges.** `0..10` is 0 to 9. For 1 to 10 write `1..=10`.

**4. A `match` that misses cases** — `non-exhaustive patterns`. Add the missing ones, or `_`.

```rust
fn main() {
    let n: u8 = 3;
    let s = match n {
        0 => "none",
        1 => "one",
    };
}
```

*The compiler says:*

```text
error[E0004]: non-exhaustive patterns: `2_u8..=u8::MAX` not covered
 --> src/main.rs:3:19
  |
3 |     let s = match n {
  |                   ^ pattern `2_u8..=u8::MAX` not covered
  |
  = note: the matched value is of type `u8`
help: ensure that all possible cases are being handled by adding a match arm with a wildcard pattern or an explicit pattern as shown
  |
5 ~         1 => "one",
6 ~         2_u8..=u8::MAX => todo!(),
  |
```
