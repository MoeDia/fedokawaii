---
id: rs-enum
title: an enum, variants with data
part: rust
chapter: 54
minutes: 8
needs: [rs-structs-practice]
optional: no
---

> **In this chapter**
>
> - enums: a value that is one of several kinds, each with its own data
> - `match`: handle every kind, checked by the compiler
> - `Option`: Rust's answer to "maybe nothing" — no null, ever
> - `if let`, `let else`, and methods on enums
> - the checkpoint for level 2: a bank with commands

## 54.1 an enum

An **enum** (*enumeration*) is a type whose value is exactly one of a list of **variants**:

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
enum Direction {
    North,
    East,
    South,
    West,
}

fn turn_right(d: Direction) -> Direction {
    match d {
        Direction::North => Direction::East,
        Direction::East => Direction::South,
        Direction::South => Direction::West,
        Direction::West => Direction::North,
    }
}

fn main() {
    let mut d = Direction::North;
    for _ in 0..5 {
        print!("{:?} → ", d);
        d = turn_right(d);
    }
    println!("{:?}", d);
}
```

*You should see:*

```text
North → East → South → West → North → East
```

## 54.2 variants with data

Each variant can carry its own data — different for each. This is what makes Rust's enums so
useful: one type, several shapes:

```rust
#[derive(Debug)]
enum Shape {
    Circle { r: f64 },
    Rect { w: f64, h: f64 },
    Triangle(f64, f64, f64),
}

fn area(s: &Shape) -> f64 {
    match s {
        Shape::Circle { r } => std::f64::consts::PI * r * r,
        Shape::Rect { w, h } => w * h,
        Shape::Triangle(a, b, c) => {
            let p = (a + b + c) / 2.0;
            (p * (p - a) * (p - b) * (p - c)).sqrt()
        }
    }
}

fn main() {
    let shapes = [Shape::Circle { r: 1.0 }, Shape::Rect { w: 2.0, h: 3.0 }, Shape::Triangle(3.0, 4.0, 5.0)];
    for s in &shapes {
        println!("{:?} → {:.2}", s, area(s));
    }
}
```

*You should see:*

```text
Circle { r: 1.0 } → 3.14
Rect { w: 2.0, h: 3.0 } → 6.00
Triangle(3.0, 4.0, 5.0) → 6.00
```

*(in the `match`, `Shape::Rect { w, h }` takes the variant apart and names its fields — a
**pattern**)*
