---
id: rs-enums-practice
title: practice
part: rust
chapter: 54
minutes: 18
needs: [rs-bank]
optional: no
---

**54.1 ★ Weekday.** `enum Day { Mon, … Sun }` and `fn is_weekend(d: Day) -> bool` with one `match` arm using `|`.

<!-- solution 54.1 -->
```rust
#[derive(Debug, Clone, Copy)]
enum Day {
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,
    Sun,
}

fn is_weekend(d: Day) -> bool {
    match d {
        Day::Sat | Day::Sun => true,
        _ => false,
    }
}

fn main() {
    for d in [Day::Mon, Day::Tue, Day::Wed, Day::Thu, Day::Fri, Day::Sat, Day::Sun] {
        print!("{:?}:{} ", d, is_weekend(d));
    }
    println!();
}
```

*You should see:*

```text
Mon:false Tue:false Wed:false Thu:false Fri:false Sat:true Sun:true
```
<!-- /solution -->

**54.2 ★ Safe division.** `fn divide(a: f64, b: f64) -> Option<f64>`, `None` for `b == 0.0`; print two results with `match`.

<!-- solution 54.2 -->
```rust
fn divide(a: f64, b: f64) -> Option<f64> {
    if b == 0.0 { None } else { Some(a / b) }
}

fn main() {
    for (a, b) in [(1.0, 4.0), (1.0, 0.0)] {
        match divide(a, b) {
            Some(q) => println!("{a}/{b} = {q}"),
            None => println!("{a}/{b}: cannot divide by zero"),
        }
    }
}
```

*You should see:*

```text
1/4 = 0.25
1/0: cannot divide by zero
```
<!-- /solution -->

**54.3 ★ unwrap_or.** Print the first element of an empty `Vec<i32>`, or `-1`, in one line.

<!-- solution 54.3 -->
```rust
fn main() {
    let v: Vec<i32> = Vec::new();
    println!("{}", v.first().copied().unwrap_or(-1));
}
```

*You should see:*

```text
-1
```
<!-- /solution -->

**54.4 ★★ Coins.** `enum Coin { Fils25, Fils50, Dirham }` with a `value_in_fils` method; total a list of coins.

<!-- solution 54.4 -->
```rust
enum Coin {
    Fils25,
    Fils50,
    Dirham,
}

impl Coin {
    fn value_in_fils(&self) -> u32 {
        match self {
            Coin::Fils25 => 25,
            Coin::Fils50 => 50,
            Coin::Dirham => 100,
        }
    }
}

fn main() {
    let purse = [Coin::Dirham, Coin::Fils50, Coin::Fils25, Coin::Fils25];
    let total: u32 = purse.iter().map(|c| c.value_in_fils()).sum();
    println!("{total} fils");
}
```

*You should see:*

```text
200 fils
```
<!-- /solution -->

**54.5 ★★ Traffic light.** `enum Light { Red, Amber, Green }` with `next(self) -> Light` and `seconds(&self) -> u32`; step
through six changes.

<!-- solution 54.5 -->
```rust
#[derive(Debug, Clone, Copy)]
enum Light {
    Red,
    Amber,
    Green,
}

impl Light {
    fn next(self) -> Light {
        match self {
            Light::Red => Light::Green,
            Light::Green => Light::Amber,
            Light::Amber => Light::Red,
        }
    }
    fn seconds(&self) -> u32 {
        match self {
            Light::Red => 30,
            Light::Green => 25,
            Light::Amber => 4,
        }
    }
}

fn main() {
    let mut l = Light::Red;
    for _ in 0..6 {
        print!("{:?}({}) ", l, l.seconds());
        l = l.next();
    }
    println!();
}
```

*You should see:*

```text
Red(30) Green(25) Amber(4) Red(30) Green(25) Amber(4)
```
<!-- /solution -->

**54.6 ★★ Parse a grade.** `fn grade(score: u32) -> Option<char>`: `None` above 100; `A`/`B`/`C`/`F` with range patterns
(`90..=100 => …`).

<!-- solution 54.6 -->
```rust
fn grade(score: u32) -> Option<char> {
    match score {
        90..=100 => Some('A'),
        75..=89 => Some('B'),
        60..=74 => Some('C'),
        0..=59 => Some('F'),
        _ => None,
    }
}

fn main() {
    println!("{:?} {:?} {:?}", grade(95), grade(61), grade(120));
}
```

*You should see:*

```text
Some('A') Some('C') None
```
<!-- /solution -->
