---
id: rs-trait-params
title: traits as parameters
part: rust
chapter: 57
minutes: 4
needs: [rs-trait]
optional: no
---

## 57.2 traits as parameters

A function can accept *any* type that implements a trait:

```rust
trait Area {
    fn area(&self) -> f64;
}

struct Square(f64);
struct Circle(f64);

impl Area for Square {
    fn area(&self) -> f64 {
        self.0 * self.0
    }
}

impl Area for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.0 * self.0
    }
}

fn report(shape: &impl Area) {
    println!("area {:.2}", shape.area());
}

fn main() {
    report(&Square(2.0));
    report(&Circle(1.0));
}
```

*You should see:*

```text
area 4.00
area 3.14
```

*(`&impl Area` reads: "a reference to some type that implements `Area`")*
