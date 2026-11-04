---
id: rs-struct
title: a struct, printed
part: rust
chapter: 53
minutes: 7
needs: [rs-own-practice, rs-borrow-practice]
optional: no
---

> **In this chapter**
>
> - structs: your own types, with named fields
> - `impl`: methods and associated functions (`new`)
> - `&self`, `&mut self`, `self`: borrowing applied to methods
> - `#[derive(Debug, Clone, PartialEq)]`

## 53.1 a struct

A **struct** groups named values into one new type — Python's dataclass, with types on every
field:

```rust
struct User {
    name: String,
    age: u32,
    active: bool,
}

fn main() {
    let mut u = User { name: String::from("Sara"), age: 31, active: true };
    u.age += 1;
    println!("{} is {} (active: {})", u.name, u.age, u.active);
}
```

*You should see:*

```text
Sara is 32 (active: true)
```

*(to change a field, the whole variable must be `mut`)*

When a variable has the field's name, write it once — the **shorthand**; and `..other` fills the
remaining fields from another value:

```rust
struct User {
    name: String,
    age: u32,
    active: bool,
}

fn main() {
    let name = String::from("Omar");
    let age = 28;
    let a = User { name, age, active: true };
    let b = User { name: String::from("Lina"), ..a };
    println!("{} {} {}", b.name, b.age, b.active);
}
```

*You should see:*

```text
Lina 28 true
```

## 53.2 printing a struct: derive Debug

`println!("{}", u)` does not work for your own types: Rust does not guess how to show them. Ask
it to write the debug form for you with `#[derive(Debug)]`, then print with `{:?}` — or `{:#?}`
for one field per line:

```rust
#[derive(Debug)]
struct Point {
    x: f64,
    y: f64,
}

fn main() {
    let p = Point { x: 1.5, y: -2.0 };
    println!("{:?}", p);
    println!("{:#?}", p);
}
```

*You should see:*

```text
Point { x: 1.5, y: -2.0 }
Point {
    x: 1.5,
    y: -2.0,
}
```
