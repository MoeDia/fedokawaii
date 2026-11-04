---
id: rs-module-files
title: modules in files
part: rust
chapter: 59
minutes: 4
needs: [rs-rooms]
optional: no
---

## 59.2 modules in files

In a real project each module is its own file. `mod name;` (with a semicolon) in `main.rs` tells
cargo to read `src/name.rs`:

```text
$ cargo new -q shapes
```

`shapes/src/geometry.rs`:

```rust
//! Areas of simple shapes.

/// The area of a rectangle.
pub fn rect(w: f64, h: f64) -> f64 {
    w * h
}

/// The area of a circle of radius `r`.
pub fn circle(r: f64) -> f64 {
    std::f64::consts::PI * r * r
}
```

`shapes/src/main.rs`:

```rust
mod geometry;

use geometry::{circle, rect};

fn main() {
    println!("{} {:.3}", rect(2.0, 3.0), circle(1.0));
}
```

```text
$ cd shapes && cargo run -q
6 3.142
$ cd shapes && find src | sort
src
src/geometry.rs
src/main.rs
```

*(`///` is a **doc comment**: `cargo doc --open` turns it into documentation pages. `//!`
documents the module itself)*

A module with sub-modules is a folder: `src/geometry/mod.rs`, or `src/geometry.rs` beside a
`src/geometry/` folder holding the sub-modules.
