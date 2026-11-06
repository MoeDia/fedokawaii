---
id: rs-traits-projects
title: projects
part: rust
chapter: 57
minutes: 180
needs: [rs-traits-practice]
optional: yes
---

**57.7 ★★★ Multiply money.** For chapter 57's `Money`, implement `Add` and `Mul<i64>` (`use std::ops::Mul;`), so
`Money { fils: 1250 } * 3 + Money { fils: 50 }` prints `38.00 AED`.

<!-- solution 57.7 -->
```rust
use std::fmt;
use std::ops::{Add, Mul};

#[derive(Clone, Copy)]
struct Money {
    fils: i64,
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}.{:02} AED", self.fils / 100, self.fils % 100)
    }
}

impl Add for Money {
    type Output = Money;
    fn add(self, o: Money) -> Money {
        Money { fils: self.fils + o.fils }
    }
}

impl Mul<i64> for Money {
    type Output = Money;
    fn mul(self, n: i64) -> Money {
        Money { fils: self.fils * n }
    }
}

fn main() {
    println!("{}", Money { fils: 1250 } * 3 + Money { fils: 50 });
}
```

*You should see:*

```text
38.00 AED
```
<!-- /solution -->

**57.8 ★★★ A zoo of trait objects.** `trait Animal { fn name(&self) -> String; fn sound(&self) -> String; fn legs(&self) -> u32 { 4 } }`
with three animals (one a bird with 2 legs), kept in a `Vec<Box<dyn Animal>>`; print each and the
total number of legs.

<!-- solution 57.8 -->
```rust
trait Animal {
    fn name(&self) -> String;
    fn sound(&self) -> String;
    fn legs(&self) -> u32 {
        4
    }
}

struct Cat;
struct Cow;
struct Crow;

impl Animal for Cat {
    fn name(&self) -> String { "cat".into() }
    fn sound(&self) -> String { "meow".into() }
}
impl Animal for Cow {
    fn name(&self) -> String { "cow".into() }
    fn sound(&self) -> String { "moo".into() }
}
impl Animal for Crow {
    fn name(&self) -> String { "crow".into() }
    fn sound(&self) -> String { "caw".into() }
    fn legs(&self) -> u32 { 2 }
}

fn main() {
    let zoo: Vec<Box<dyn Animal>> = vec![Box::new(Cat), Box::new(Cow), Box::new(Crow)];
    for a in &zoo {
        println!("{} says {}", a.name(), a.sound());
    }
    println!("{} legs", zoo.iter().map(|a| a.legs()).sum::<u32>());
}
```

*You should see:*

```text
cat says meow
cow says moo
crow says caw
10 legs
```
<!-- /solution -->

**57.9 ★★★★ A generic stack with Display.** `struct Stack<T> { items: Vec<T> }` with `push`, `pop`, `peek`, `len`, and `impl<T: Display> Display
for Stack<T>` printing `[a | b | c>` (top on the right). Use it with numbers and with strings.

<!-- solution 57.9 -->
```rust
use std::fmt;

struct Stack<T> {
    items: Vec<T>,
}

impl<T> Stack<T> {
    fn new() -> Self {
        Stack { items: Vec::new() }
    }
    fn push(&mut self, x: T) {
        self.items.push(x);
    }
    fn pop(&mut self) -> Option<T> {
        self.items.pop()
    }
    fn peek(&self) -> Option<&T> {
        self.items.last()
    }
    fn len(&self) -> usize {
        self.items.len()
    }
}

impl<T: fmt::Display> fmt::Display for Stack<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let parts: Vec<String> = self.items.iter().map(|i| i.to_string()).collect();
        write!(f, "[{}>", parts.join(" | "))
    }
}

fn main() {
    let mut a = Stack::new();
    a.push(1);
    a.push(2);
    a.push(3);
    a.pop();
    let mut b = Stack::new();
    b.push("tea");
    b.push("rice");
    println!("{a} {b} {:?} {}", b.peek(), b.len());
}
```

*You should see:*

```text
[1 | 2> [tea | rice> Some("rice") 2
```
<!-- /solution -->
