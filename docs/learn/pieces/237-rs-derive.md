---
id: rs-derive
title: deriving more; common mistakes
part: rust
chapter: 53
minutes: 7
needs: [rs-tuple-structs]
optional: no
---

## 53.6 deriving more

`#[derive(...)]` writes common traits (chapter 57) for you:

| Derive | Gives |
|---|---|
| `Debug` | `{:?}` printing |
| `Clone` | `.clone()` |
| `Copy` | copies instead of moves (only if every field is Copy) |
| `PartialEq` | `==` and `!=`, field by field |
| `PartialOrd` | `<`, `>` — field by field, in order |
| `Default` | `Type::default()`: zeros, empty strings, `false` |
| `Hash`, `Eq` | use as a `HashMap` key or in a `HashSet` |

```rust
#[derive(Debug, Clone, PartialEq, Default)]
struct Settings {
    theme: String,
    font_size: u32,
    beta: bool,
}

fn main() {
    let a = Settings { theme: "dark".into(), font_size: 12, ..Default::default() };
    let mut b = a.clone();
    println!("{}", a == b);
    b.font_size = 14;
    println!("{} {:?}", a == b, Settings::default());
}
```

*You should see:*

```text
true
false Settings { theme: "", font_size: 0, beta: false }
```

*(`"dark".into()` turns the `&str` into the `String` the field wants: `.into()` converts to
whatever type is needed there)*

## 53.7 common mistakes

**1. Forgetting `&` on `self`.** `fn area(self)` takes ownership: after `r.area()`, `r` is gone.
Read-only methods take `&self`.

**2. Changing through `&self`.** `cannot assign to self.w, which is behind a & reference` —
the method needs `&mut self`, and the variable must be `mut`.

```rust
struct Counter {
    n: u32,
}

impl Counter {
    fn click(&self) {
        self.n += 1;
    }
}

fn main() {
    let c = Counter { n: 0 };
    c.click();
}
```

*The compiler says:*

```text
error[E0594]: cannot assign to `self.n`, which is behind a `&` reference
 --> src/main.rs:7:9
  |
7 |         self.n += 1;
  |         ^^^^^^^^^^^ `self` is a `&` reference, so it cannot be written to
  |
help: consider changing this to be a mutable reference
  |
6 |     fn click(&mut self) {
  |               +++
```

**3. `{}` for a struct.** `doesn't implement std::fmt::Display` — use `{:?}` with
`#[derive(Debug)]`, or write `Display` yourself (chapter 57).
