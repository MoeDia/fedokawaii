---
id: rs-option-work
title: working with Option; methods on enums
part: rust
chapter: 54
minutes: 9
needs: [rs-option]
optional: no
---

## 54.6 working with Option

`match` always works; these methods are shorter for common cases:

```rust
fn main() {
    let some: Option<i32> = Some(4);
    let none: Option<i32> = None;
    println!("{} {}", some.unwrap_or(0), none.unwrap_or(0));
    println!("{:?} {:?}", some.map(|n| n * 10), none.map(|n| n * 10));
    println!("{} {}", some.is_some(), none.is_none());
    if let Some(n) = some {
        println!("got {n}");
    }
}
```

*You should see:*

```text
4 0
Some(40) None
true true
got 4
```

| Write | Does |
|---|---|
| `x.unwrap_or(d)` | the value, or `d` if None |
| `x.map(f)` | `Some(f(v))`, or None |
| `if let Some(v) = x { … }` | run the block only when there is a value |
| `let Some(v) = x else { return … };` | take the value, or leave the function |
| `x.unwrap()` | the value — or **panic** if None. Only when None truly cannot happen |
| `x.expect("why")` | the same, with your message in the panic |

`let … else` keeps the happy path unindented:

```rust
fn initials(name: &str) -> String {
    let Some(first) = name.chars().next() else {
        return String::from("?");
    };
    first.to_uppercase().to_string()
}

fn main() {
    println!("{} {}", initials("sara"), initials(""));
}
```

*You should see:*

```text
S ?
```

## 54.7 methods on enums

`impl` works for enums as for structs:

```rust
#[derive(Debug)]
enum Command {
    Deposit(u64),
    Withdraw(u64),
    Balance,
    Quit,
}

impl Command {
    fn parse(line: &str) -> Option<Command> {
        let words: Vec<&str> = line.split_whitespace().collect();
        match words.as_slice() {
            ["deposit", n] => Some(Command::Deposit(n.parse().ok()?)),
            ["withdraw", n] => Some(Command::Withdraw(n.parse().ok()?)),
            ["balance"] => Some(Command::Balance),
            ["quit"] => Some(Command::Quit),
            _ => None,
        }
    }
}

fn main() {
    for line in ["deposit 50", "withdraw x", "balance", "fly away"] {
        println!("{line:<12} → {:?}", Command::parse(line));
    }
}
```

*You should see:*

```text
deposit 50   → Some(Deposit(50))
withdraw x   → None
balance      → Some(Balance)
fly away     → None
```

*(`.ok()?` — if the number does not parse, return `None` from `parse` at once. Chapter 56 explains
`?`; matching on `words.as_slice()` matches the list of words against shapes)*

## 54.8 common mistakes

**1. `non-exhaustive patterns`** — a variant is missing from a `match`. Handle it; reach for `_`
only when "everything else" truly is one case.

**2. `unwrap()` everywhere.** Each is a possible crash. Use `match`, `if let`, `unwrap_or`, or `?`.

**3. Forgetting the enum's name.** `North` alone is not found; write `Direction::North` (or
`use Direction::*;` to bring the names in).
