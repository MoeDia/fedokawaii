---
id: rs-std-traits
title: standard traits you implement
part: rust
chapter: 57
minutes: 10
needs: [rs-trait-params]
optional: no
---

## 57.3 standard traits you implement

Much of Rust's convenience comes from a handful of standard traits. Implement them, and your type
works with `println!`, `+`, `sort`, `.into()`:

**Display** — how `{}` shows your type:

```rust
use std::fmt;

struct Money {
    fils: i64,
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}.{:02} AED", self.fils / 100, self.fils % 100)
    }
}

fn main() {
    let m = Money { fils: 1250 };
    println!("{m}");
    let s = m.to_string();
    println!("{} characters", s.len());
}
```

*You should see:*

```text
12.50 AED
9 characters
```

*(implementing `Display` gives `.to_string()` for free)*

**Add** — the `+` sign; **From** — converting one type into another, which also gives `.into()`:

```rust
use std::ops::Add;

#[derive(Debug, Clone, Copy, PartialEq)]
struct V2 {
    x: f64,
    y: f64,
}

impl Add for V2 {
    type Output = V2;
    fn add(self, o: V2) -> V2 {
        V2 { x: self.x + o.x, y: self.y + o.y }
    }
}

impl From<(f64, f64)> for V2 {
    fn from(t: (f64, f64)) -> V2 {
        V2 { x: t.0, y: t.1 }
    }
}

fn main() {
    let a = V2::from((1.0, 2.0));
    let b: V2 = (0.5, 0.5).into();
    println!("{:?}", a + b);
}
```

*You should see:*

```text
V2 { x: 1.5, y: 2.5 }
```

**PartialOrd / Ord** — comparison and sorting. Deriving compares field by field in order:

```rust
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
struct Version {
    major: u32,
    minor: u32,
    patch: u32,
}

fn main() {
    let mut vs = vec![
        Version { major: 1, minor: 10, patch: 0 },
        Version { major: 1, minor: 2, patch: 7 },
        Version { major: 0, minor: 9, patch: 9 },
    ];
    vs.sort();
    for v in &vs {
        println!("{}.{}.{}", v.major, v.minor, v.patch);
    }
    println!("{}", vs[0] < vs[1]);
}
```

*You should see:*

```text
0.9.9
1.2.7
1.10.0
true
```
