---
id: rs-tuples
title: bool, char, text, tuples, arrays
part: rust
chapter: 49
minutes: 4
needs: [rs-numbers]
optional: no
---

## 49.4 bool, char and text

```rust
fn main() {
    let ready: bool = 3 > 2;
    let letter: char = 'k';
    let kanji: char = '猫';
    let name: &str = "Sharjah";
    let mut owned: String = String::from("hello");
    owned.push_str(", world");
    println!("{ready} {letter} {kanji} {name} {owned}");
    println!("{} {}", name.len(), owned.to_uppercase());
}
```

*You should see:*

```text
true k 猫 Sharjah hello, world
7 HELLO, WORLD
```

| Type | Is |
|---|---|
| `bool` | `true` or `false` |
| `char` | one character, in single quotes: `'a'`, `'猫'`, `'é'` |
| `&str` | a piece of text you look at, in double quotes: `"hello"` |
| `String` | text you own and can grow: `String::from("hello")` |

Why two kinds of text? It is about *ownership*, Rust's central idea (chapter 51). For now:
literals in quotes are `&str`; when you need to build or change text, make a `String`.

## 49.5 tuples and arrays

```rust
fn main() {
    let point: (i32, i32) = (3, 4);
    let (x, y) = point;
    println!("{} {} {x} {y}", point.0, point.1);

    let days: [&str; 3] = ["mon", "tue", "wed"];
    let zeros = [0; 5];
    println!("{} {} {:?} {:?}", days[0], days.len(), days, zeros);
}
```

*You should see:*

```text
3 4 3 4
mon 3 ["mon", "tue", "wed"] [0, 0, 0, 0, 0]
```

*(`{:?}` prints a value in its **debug** form — how Rust shows a whole tuple, array or list.
An array's size is part of its type: `[&str; 3]`. For a list that grows, chapter 55's `Vec`)*
