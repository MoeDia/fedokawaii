---
id: rs-structs-practice
title: practice
part: rust
chapter: 53
minutes: 18
needs: [rs-derive]
optional: no
---

**53.1 ★ A book.** `struct Book { title: String, year: u16 }` with `#[derive(Debug)]`; make two and print them with
`{:?}`.

<!-- solution 53.1 -->
```rust
#[derive(Debug)]
struct Book {
    title: String,
    year: u16,
}

fn main() {
    let a = Book { title: "Dune".into(), year: 1965 };
    let b = Book { title: "Emma".into(), year: 1815 };
    println!("{:?}\n{:?}", a, b);
}
```

*You should see:*

```text
Book { title: "Dune", year: 1965 }
Book { title: "Emma", year: 1815 }
```
<!-- /solution -->

**53.2 ★ Circle.** `struct Circle { r: f64 }` with `area` and `circumference` methods.

<!-- solution 53.2 -->
```rust
struct Circle {
    r: f64,
}

impl Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.r * self.r
    }
    fn circumference(&self) -> f64 {
        2.0 * std::f64::consts::PI * self.r
    }
}

fn main() {
    let c = Circle { r: 2.0 };
    println!("{:.2} {:.2}", c.area(), c.circumference());
}
```

*You should see:*

```text
12.57 12.57
```
<!-- /solution -->

**53.3 ★ A counter.** `Counter` with `new()`, `click(&mut self)`, `reset(&mut self)` and `value(&self)`.

<!-- solution 53.3 -->
```rust
struct Counter {
    n: u32,
}

impl Counter {
    fn new() -> Self {
        Counter { n: 0 }
    }
    fn click(&mut self) {
        self.n += 1;
    }
    fn reset(&mut self) {
        self.n = 0;
    }
    fn value(&self) -> u32 {
        self.n
    }
}

fn main() {
    let mut c = Counter::new();
    c.click();
    c.click();
    print!("{} ", c.value());
    c.reset();
    println!("{}", c.value());
}
```

*You should see:*

```text
2 0
```
<!-- /solution -->

**53.4 ★★ Account.** `Account { owner: String, balance: i64 }` (in fils) with `deposit`, and `withdraw` returning
`bool` (false, and no change, if too little money).

<!-- solution 53.4 -->
```rust
struct Account {
    owner: String,
    balance: i64,
}

impl Account {
    fn deposit(&mut self, amount: i64) {
        self.balance += amount;
    }
    fn withdraw(&mut self, amount: i64) -> bool {
        if amount > self.balance {
            return false;
        }
        self.balance -= amount;
        true
    }
}

fn main() {
    let mut a = Account { owner: "Sara".into(), balance: 1000 };
    a.deposit(500);
    let too_much = a.withdraw(2000);
    let fine = a.withdraw(300);
    println!("{} {too_much} {fine} {}", a.owner, a.balance);
}
```

*You should see:*

```text
Sara false true 1200
```
<!-- /solution -->

**53.5 ★★ Vector maths.** `#[derive(Debug, Clone, Copy, PartialEq)] struct V2 { x: f64, y: f64 }` with `add`, `scale`,
`dot` and `length`.

<!-- solution 53.5 -->
```rust
#[derive(Debug, Clone, Copy, PartialEq)]
struct V2 {
    x: f64,
    y: f64,
}

impl V2 {
    fn add(self, o: V2) -> V2 {
        V2 { x: self.x + o.x, y: self.y + o.y }
    }
    fn scale(self, k: f64) -> V2 {
        V2 { x: self.x * k, y: self.y * k }
    }
    fn dot(self, o: V2) -> f64 {
        self.x * o.x + self.y * o.y
    }
    fn length(self) -> f64 {
        self.dot(self).sqrt()
    }
}

fn main() {
    let a = V2 { x: 3.0, y: 4.0 };
    println!("{:?} {:?} {} {}", a.add(a), a.scale(0.5), a.dot(a), a.length());
}
```

*You should see:*

```text
V2 { x: 6.0, y: 8.0 } V2 { x: 1.5, y: 2.0 } 25 5
```
<!-- /solution -->

**53.6 ★★ Newtypes.** `struct Fils(i64)` and `struct Dirham(f64)`, with `fn to_dirham(f: Fils) -> Dirham`. Show that
passing a `Dirham` where `Fils` is wanted does not compile.

<!-- solution 53.6 -->
```rust
#[derive(Debug)]
struct Fils(i64);
#[derive(Debug)]
struct Dirham(f64);

fn to_dirham(f: Fils) -> Dirham {
    Dirham(f.0 as f64 / 100.0)
}

fn main() {
    println!("{:?}", to_dirham(Fils(1250)));
    // to_dirham(Dirham(12.5));  // error[E0308]: mismatched types: expected `Fils`, found `Dirham`
}
```

*You should see:*

```text
Dirham(12.5)
```
<!-- /solution -->
