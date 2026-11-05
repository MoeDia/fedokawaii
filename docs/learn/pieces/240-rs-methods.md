---
id: rs-methods
title: methods with impl
part: rust
chapter: 53
minutes: 4
needs: [rs-struct]
optional: no
---

## 53.3 methods with impl

Functions that belong to a type go in an `impl` block. A **method** takes `self` — the value it
is called on — as its first parameter, almost always borrowed:

```rust
#[derive(Debug)]
struct Rect {
    w: f64,
    h: f64,
}

impl Rect {
    fn area(&self) -> f64 {
        self.w * self.h
    }

    fn scale(&mut self, k: f64) {
        self.w *= k;
        self.h *= k;
    }

    fn fits_in(&self, other: &Rect) -> bool {
        self.w <= other.w && self.h <= other.h
    }
}

fn main() {
    let mut r = Rect { w: 3.0, h: 4.0 };
    println!("{}", r.area());
    r.scale(2.0);
    println!("{:?} {}", r, r.fits_in(&Rect { w: 10.0, h: 10.0 }));
}
```

*You should see:*

```text
12
Rect { w: 6.0, h: 8.0 } true
```

| First parameter | The method | Use for |
|---|---|---|
| `&self` | borrows the value, to read | most methods: `area`, `len`, `name` |
| `&mut self` | borrows it, to change | `scale`, `push`, `deposit` |
| `self` | takes ownership: the value is used up | turning it into something else: `into_string` |
