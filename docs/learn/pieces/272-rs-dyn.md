---
id: rs-dyn
title: generic structs; dyn Trait
part: rust
chapter: 57
minutes: 8
needs: [rs-generics]
optional: no
---

## 57.5 generic structs

```rust
#[derive(Debug)]
struct Pair<T> {
    a: T,
    b: T,
}

impl<T: PartialOrd + Copy> Pair<T> {
    fn bigger(&self) -> T {
        if self.a > self.b { self.a } else { self.b }
    }
}

fn main() {
    let p = Pair { a: 3, b: 8 };
    let q = Pair { a: 2.5, b: -1.0 };
    println!("{:?} {} {}", p, p.bigger(), q.bigger());
}
```

*You should see:*

```text
Pair { a: 3, b: 8 } 8 2.5
```

`Vec<T>`, `Option<T>`, `Result<T, E>` and `HashMap<K, V>` are all generic structs and enums
like this one.

> **Word — monomorphisation.** For each type you use a generic with, the compiler writes a
> separate copy of the code — `largest` for `i32`, another for `f64`. So generics cost nothing
> when the program runs: they are as fast as code written by hand for each type.

## 57.6 dyn Trait: different types in one list

A `Vec` holds one type. To keep circles and squares in one list, store them as **trait objects**,
`Box<dyn Area>` — "some type that implements `Area`, decided when the program runs":

```rust
trait Area {
    fn area(&self) -> f64;
    fn name(&self) -> &str;
}

struct Square(f64);
struct Circle(f64);

impl Area for Square {
    fn area(&self) -> f64 { self.0 * self.0 }
    fn name(&self) -> &str { "square" }
}

impl Area for Circle {
    fn area(&self) -> f64 { 3.14159 * self.0 * self.0 }
    fn name(&self) -> &str { "circle" }
}

fn main() {
    let shapes: Vec<Box<dyn Area>> = vec![Box::new(Square(2.0)), Box::new(Circle(1.0)), Box::new(Square(3.0))];
    let mut total = 0.0;
    for s in &shapes {
        println!("{:<7}{:>6.2}", s.name(), s.area());
        total += s.area();
    }
    println!("total {total:.2}");
}
```

*You should see:*

```text
square   4.00
circle   3.14
square   9.00
total 16.14
```

| | `impl Trait` / generics | `dyn Trait` |
|---|---|---|
| the type is chosen | when compiling | when running |
| speed | fastest: a copy per type | one small extra step per call |
| mixed types in one collection | no | yes |
| use for | almost everything | plugins, lists of different things |

## 57.7 common mistakes

**1. A missing bound.** `binary operation > cannot be applied to type T` — add the trait the
operation needs (`T: PartialOrd`); the compiler usually suggests it.

**2. A trait not in scope.** A trait's methods work only where the trait is imported:
`use std::fmt::Write;` before `write!` into a `String`, `use std::io::Read;` for `read_to_string`
on a file.

**3. Implementing a foreign trait for a foreign type** (`Display` for `Vec<i32>`) is not allowed —
the *orphan rule*. Wrap it in your own type: `struct Scores(Vec<i32>);`.
