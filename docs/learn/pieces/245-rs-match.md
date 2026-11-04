---
id: rs-match
title: match must cover everything; patterns
part: rust
chapter: 54
minutes: 8
needs: [rs-enum]
optional: no
---

## 54.3 match must cover everything

Add a variant, and every `match` that forgot it stops compiling — the compiler finds every place
your program must learn about the new case:

```rust
enum Light {
    Red,
    Amber,
    Green,
}

fn wait(l: Light) -> u32 {
    match l {
        Light::Red => 30,
        Light::Green => 0,
    }
}

fn main() {}
```

*The compiler says:*

```text
error[E0004]: non-exhaustive patterns: `Light::Amber` not covered
  --> src/main.rs:8:11
   |
 8 |     match l {
   |           ^ pattern `Light::Amber` not covered
   |
note: `Light` defined here
  --> src/main.rs:1:6
   |
 1 | enum Light {
   |      ^^^^^
 2 |     Red,
 3 |     Amber,
   |     ----- not covered
   = note: the matched value is of type `Light`
help: ensure that all possible cases are being handled by adding a match arm with a wildcard pattern or an explicit pattern as shown
   |
10 ~         Light::Green => 0,
11 ~         Light::Amber => todo!(),
   |
```

## 54.4 patterns

`match` patterns can test values, ranges, several options, and add conditions (**guards**):

```rust
fn classify(p: (i32, i32)) -> String {
    match p {
        (0, 0) => "the origin".to_string(),
        (x, 0) | (0, x) => format!("on an axis at {x}"),
        (x, y) if x == y => format!("on the diagonal at {x}"),
        (x, y) if x > 0 && y > 0 => "top right".to_string(),
        _ => "somewhere else".to_string(),
    }
}

fn main() {
    for p in [(0, 0), (5, 0), (0, -2), (3, 3), (1, 7), (-1, 4)] {
        println!("{:?}: {}", p, classify(p));
    }
}
```

*You should see:*

```text
(0, 0): the origin
(5, 0): on an axis at 5
(0, -2): on an axis at -2
(3, 3): on the diagonal at 3
(1, 7): top right
(-1, 4): somewhere else
```

*(`format!` is `println!` that gives back a `String` instead of printing it)*
