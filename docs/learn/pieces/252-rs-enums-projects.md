---
id: rs-enums-projects
title: projects
part: rust
chapter: 54
minutes: 180
needs: [rs-enums-practice]
optional: yes
---

**54.7 ★★★ A calculator enum.** `enum Expr { Num(f64), Add(Box<Expr>, Box<Expr>), Mul(Box<Expr>, Box<Expr>) }` and a recursive
`fn eval(e: &Expr) -> f64`. Evaluate `(2 + 3) × 4`. (`Box` puts a value on the heap, so an enum
can contain itself.)

<!-- solution 54.7 -->
```rust
enum Expr {
    Num(f64),
    Add(Box<Expr>, Box<Expr>),
    Mul(Box<Expr>, Box<Expr>),
}

fn eval(e: &Expr) -> f64 {
    match e {
        Expr::Num(n) => *n,
        Expr::Add(a, b) => eval(a) + eval(b),
        Expr::Mul(a, b) => eval(a) * eval(b),
    }
}

fn main() {
    use Expr::*;
    let e = Mul(Box::new(Add(Box::new(Num(2.0)), Box::new(Num(3.0)))), Box::new(Num(4.0)));
    println!("{}", eval(&e));
}
```

*You should see:*

```text
20
```
<!-- /solution -->

**54.8 ★★★ Find a user.** `struct User { id: u32, name: String }`; `fn find(users: &[User], id: u32) -> Option<&User>`; print
the name for id 2, or `nobody` — with `map` and `unwrap_or`.

<!-- solution 54.8 -->
```rust
struct User {
    id: u32,
    name: String,
}

fn find(users: &[User], id: u32) -> Option<&User> {
    users.iter().find(|u| u.id == id)
}

fn main() {
    let users = vec![User { id: 1, name: "Sara".into() }, User { id: 2, name: "Omar".into() }];
    for id in [2, 9] {
        println!("{}", find(&users, id).map(|u| u.name.as_str()).unwrap_or("nobody"));
    }
}
```

*You should see:*

```text
Omar
nobody
```
<!-- /solution -->

**54.9 ★★★★ A tiny state machine.** A vending machine: `enum State { Idle, HasCoins(u32), Dispensing }` and
`enum Event { Coin(u32), Choose(u32), Cancel }`, with `fn step(s: State, e: Event) -> (State, String)`
that accepts coins, dispenses when enough money was put in for the chosen price (giving
change), refunds on `Cancel`, and refuses events that do not fit the state. Run a sequence of
events and print each transition.

<!-- solution 54.9 -->
```rust
#[derive(Debug, Clone, Copy)]
enum State {
    Idle,
    HasCoins(u32),
}

#[derive(Debug, Clone, Copy)]
enum Event {
    Coin(u32),
    Choose(u32),
    Cancel,
}

fn step(s: State, e: Event) -> (State, String) {
    match (s, e) {
        (State::Idle, Event::Coin(n)) => (State::HasCoins(n), format!("credit {n}")),
        (State::HasCoins(c), Event::Coin(n)) => (State::HasCoins(c + n), format!("credit {}", c + n)),
        (State::HasCoins(c), Event::Choose(p)) if c >= p => (State::Idle, format!("dispensed, change {}", c - p)),
        (State::HasCoins(c), Event::Choose(p)) => (State::HasCoins(c), format!("need {} more", p - c)),
        (State::HasCoins(c), Event::Cancel) => (State::Idle, format!("refund {c}")),
        (State::Idle, _) => (State::Idle, "insert coins first".into()),
    }
}

fn main() {
    let mut s = State::Idle;
    for e in [Event::Choose(150), Event::Coin(100), Event::Choose(150), Event::Coin(100), Event::Choose(150), Event::Coin(50), Event::Cancel] {
        let (next, msg) = step(s, e);
        println!("{:<12} {:<10} → {msg}", format!("{:?}", s), format!("{:?}", e));
        s = next;
    }
}
```

*You should see:*

```text
Idle         Choose(150) → insert coins first
Idle         Coin(100)  → credit 100
HasCoins(100) Choose(150) → need 50 more
HasCoins(100) Coin(100)  → credit 200
HasCoins(200) Choose(150) → dispensed, change 50
Idle         Coin(50)   → credit 50
HasCoins(50) Cancel     → refund 50
```
<!-- /solution -->
