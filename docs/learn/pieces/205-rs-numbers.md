---
id: rs-numbers
title: number types
part: rust
chapter: 49
minutes: 8
needs: [rs-let]
optional: no
---

## 49.3 number types

Rust wants to know each number's type and size. It usually works it out; you write it when it
cannot, or to choose:

| Type | Holds | Range |
|---|---|---|
| `i32` | whole numbers (the default) | about ±2.1 billion |
| `i64` | larger whole numbers | about ±9.2 × 10¹⁸ |
| `u8` · `u32` · `u64` | whole numbers ≥ 0 (*u*nsigned) | 0–255 · 0–4.2 billion · 0–1.8 × 10¹⁹ |
| `usize` | sizes and indexes: as wide as the machine | 0–1.8 × 10¹⁹ on 64-bit |
| `f64` | decimals (the default) | 15–16 digits |
| `f32` | smaller decimals: what GPUs and ML models use | 6–7 digits |

```rust
fn main() {
    let a: i32 = 7;
    let b: i32 = 2;
    println!("{} {} {} {}", a + b, a * b, a / b, a % b);
    let x: f64 = 7.0;
    println!("{}", x / 2.0);
    let big: u64 = 2u64.pow(40);
    println!("{big}");
    println!("{}", i32::MAX);
    println!("{:.3}", std::f64::consts::PI);
}
```

*You should see:*

```text
9 14 3 1
3.5
1099511627776
2147483647
3.142
```

*(`7 / 2` on whole numbers is `3`: the remainder is dropped, as `//` does in Python)*

**Rust never mixes types silently.** An int and a float cannot be added until you convert one
with `as`:

```rust
fn main() {
    let n: i32 = 3;
    let x: f64 = 0.5;
    println!("{}", n + x);
}
```

*The compiler says:*

```text
error[E0277]: cannot add `f64` to `i32`
 --> src/main.rs:4:22
  |
4 |     println!("{}", n + x);
  |                      ^ no implementation for `i32 + f64`
  |
  = help: the trait `Add<f64>` is not implemented for `i32`
```

```rust
fn main() {
    let n: i32 = 3;
    let x: f64 = 0.5;
    println!("{}", n as f64 + x);
    println!("{}", 3.99_f64 as i32);
    println!("{}", 300_i32 as u8);
}
```

*You should see:*

```text
3.5
3
44
```

*(`as` to a smaller type cuts: 3.99 → 3; 300 does not fit a `u8`, and wraps to 44. Use it
knowingly)*

**Overflow** — a number too big for its type — is caught in a debug build: the program stops
rather than giving a wrong answer.

```rust
fn main() {
    let mut level: u8 = 250;
    for _ in 0..10 {
        level += 1;
    }
    println!("{level}");
}
```

*You should see:*

```text
thread 'main' (1) panicked at src/main.rs:4:9:
attempt to add with overflow
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

*(a **panic** is Rust stopping the program on purpose: something happened that must not be
ignored)*
