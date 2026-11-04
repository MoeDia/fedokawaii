---
id: rs-string
title: String in depth
part: rust
chapter: 55
minutes: 6
needs: [rs-vec-structs]
optional: no
---

## 55.3 String in depth

A `String` is a `Vec` of bytes that are always valid UTF-8 text. Build it with `push`,
`push_str`, `+`, or — usually clearest — `format!`:

```rust
fn main() {
    let mut s = String::from("tea");
    s.push(',');
    s.push_str(" rice");
    let t = s.clone() + " and milk";
    let u = format!("{t} — {} items", 3);
    println!("{s}\n{t}\n{u}");
    println!("{}", u.replace("tea", "coffee").to_uppercase());
}
```

*You should see:*

```text
tea, rice
tea, rice and milk
tea, rice and milk — 3 items
COFFEE, RICE AND MILK — 3 ITEMS
```

`len()` counts **bytes**. Count and walk letters with `.chars()`:

```rust
fn main() {
    let s = "Kyoto 京都";
    println!("{} bytes, {} chars", s.len(), s.chars().count());
    for c in s.chars().rev() {
        print!("{c}");
    }
    println!();
    let first_three: String = s.chars().take(3).collect();
    println!("{first_three}");
}
```

*You should see:*

```text
12 bytes, 8 chars
都京 otoyK
Kyo
```

Splitting, trimming, testing:

```rust
fn main() {
    let line = "  name = Sara  ";
    let parts: Vec<&str> = line.split('=').map(|p| p.trim()).collect();
    println!("{:?}", parts);
    println!("{:?}", "a,b,,c".split(',').collect::<Vec<_>>());
    println!("{:?}", "one two  three".split_whitespace().collect::<Vec<_>>());
    println!("{} {}", "fedora".starts_with("fed"), "fedora".contains("dor"));
    println!("{:?}", "key: value".split_once(": "));
    let n: i32 = " 42 ".trim().parse().unwrap();
    println!("{}", n + 1);
}
```

*You should see:*

```text
["name", "Sara"]
["a", "b", "", "c"]
["one", "two", "three"]
true true
Some(("key", "value"))
43
```

| `&str` or `String`? | |
|---|---|
| a function's parameter that only reads text | `&str` |
| a struct's field that holds text | `String` (the struct owns it) |
| a return value of text you made | `String` |
| a return value that is part of the input | `&str` (a slice of it) |
