---
id: rs-tuple-structs
title: tuple structs and unit structs
part: rust
chapter: 53
minutes: 6
needs: [rs-new]
optional: no
---

## 53.5 tuple structs and unit structs

A struct can have unnamed fields — a **tuple struct**, reached as `.0`, `.1`. It is useful to give
a plain number a meaning the compiler checks, so metres are never added to seconds by mistake:

```rust
#[derive(Debug, Clone, Copy)]
struct Metres(f64);
#[derive(Debug, Clone, Copy)]
struct Seconds(f64);

fn speed(d: Metres, t: Seconds) -> f64 {
    d.0 / t.0
}

fn main() {
    let d = Metres(100.0);
    let t = Seconds(9.58);
    println!("{:.2} m/s", speed(d, t));
}
```

*You should see:*

```text
10.44 m/s
```

```rust
#[derive(Debug, Clone, Copy)]
struct Metres(f64);
#[derive(Debug, Clone, Copy)]
struct Seconds(f64);

fn speed(d: Metres, t: Seconds) -> f64 {
    d.0 / t.0
}

fn main() {
    println!("{}", speed(Seconds(9.58), Metres(100.0)));
}
```

*The compiler says:*

```text
error[E0308]: arguments to this function are incorrect
  --> src/main.rs:11:20
   |
11 |     println!("{}", speed(Seconds(9.58), Metres(100.0)));
   |                    ^^^^^ -------------  ------------- expected `Seconds`, found `Metres`
   |                          |
   |                          expected `Metres`, found `Seconds`
   |
note: function defined here
  --> src/main.rs:6:4
   |
 6 | fn speed(d: Metres, t: Seconds) -> f64 {
   |    ^^^^^
help: swap these arguments
   |
11 -     println!("{}", speed(Seconds(9.58), Metres(100.0)));
11 +     println!("{}", speed(Metres(100.0), Seconds(9.58)));
   |
```
