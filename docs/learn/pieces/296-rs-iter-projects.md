---
id: rs-iter-projects
title: projects
part: rust
chapter: 60
minutes: 180
needs: [rs-iter-practice]
optional: yes
---

**60.7 ★★★ Counter iterator.** `struct Countdown(u32)` implementing `Iterator` from n down to 1; then `Countdown(5).map(|x| x * 10).collect::<Vec<_>>()`.

<!-- solution 60.7 -->
```rust
struct Countdown(u32);

impl Iterator for Countdown {
    type Item = u32;
    fn next(&mut self) -> Option<u32> {
        if self.0 == 0 {
            None
        } else {
            self.0 -= 1;
            Some(self.0 + 1)
        }
    }
}

fn main() {
    println!("{:?}", Countdown(5).map(|x| x * 10).collect::<Vec<_>>());
}
```

*You should see:*

```text
[50, 40, 30, 20, 10]
```
<!-- /solution -->

**60.8 ★★★ Group into a map.** From `["apple", "avocado", "banana", "blueberry", "cherry"]`, a `BTreeMap<char, Vec<&str>>` by first
letter — with `fold`, then with a `for` loop and `entry`. Which reads better?

<!-- solution 60.8 -->
```rust
use std::collections::BTreeMap;

fn main() {
    let words = ["apple", "avocado", "banana", "blueberry", "cherry"];
    let g = words.iter().fold(BTreeMap::new(), |mut m: BTreeMap<char, Vec<&str>>, w| {
        m.entry(w.chars().next().unwrap()).or_default().push(w);
        m
    });
    println!("{:?}", g);
}
```

*You should see:*

```text
{'a': ["apple", "avocado"], 'b': ["banana", "blueberry"], 'c': ["cherry"]}
```
<!-- /solution -->

**60.9 ★★★★ Primes, lazily.** An iterator of all primes (`struct Primes { found: Vec<u64>, next: u64 }`), then: the 100th prime;
the sum of primes below 1000; and the first pair of *twin primes* above 1000 (primes 2 apart) with
`windows(2)` on a collected `Vec`.

<!-- solution 60.9 -->
```rust
struct Primes {
    found: Vec<u64>,
    next: u64,
}

impl Iterator for Primes {
    type Item = u64;
    fn next(&mut self) -> Option<u64> {
        loop {
            let n = self.next;
            self.next += 1;
            if self.found.iter().take_while(|&&p| p * p <= n).all(|p| n % p != 0) {
                self.found.push(n);
                return Some(n);
            }
        }
    }
}

fn primes() -> Primes {
    Primes { found: Vec::new(), next: 2 }
}

fn main() {
    println!("{:?}", primes().nth(99));
    println!("{}", primes().take_while(|&p| p < 1000).sum::<u64>());
    let v: Vec<u64> = primes().skip_while(|&p| p < 1000).take(20).collect();
    println!("{:?}", v.windows(2).find(|w| w[1] - w[0] == 2));
}
```

*You should see:*

```text
Some(541)
76127
Some([1019, 1021])
```
<!-- /solution -->
