---
id: rs-channels
title: channels; how much faster?
part: rust
chapter: 61
minutes: 8
needs: [rs-races]
optional: no
---

## 61.5 channels: send messages

Often clearer than sharing: threads **send** results to one receiver through a channel. `mpsc`
means *multiple producers, single consumer*:

```rust
use std::sync::mpsc;
use std::thread;

fn main() {
    let (tx, rx) = mpsc::channel();
    for id in 0..3 {
        let tx = tx.clone();
        thread::spawn(move || {
            let result = (1..=10).map(|n| n * (id + 1)).sum::<u32>();
            tx.send((id, result)).unwrap();
        });
    }
    drop(tx);
    let mut results: Vec<(u32, u32)> = rx.iter().collect();
    results.sort();
    println!("{:?}", results);
}
```

*You should see:*

```text
[(0, 55), (1, 110), (2, 165)]
```

*(the loop over `rx` ends when every sender is dropped: each thread drops its clone when it
finishes, and `drop(tx)` drops the original)*

## 61.6 how much faster?

Real work, split over all the cores. `available_parallelism` says how many there are:

```rust
use std::thread;
use std::time::Instant;

fn is_prime(n: u64) -> bool {
    n >= 2 && (2..).take_while(|d| d * d <= n).all(|d| n % d != 0)
}

fn count(range: std::ops::Range<u64>) -> usize {
    range.filter(|&n| is_prime(n)).count()
}

fn main() {
    let n = 2_000_000u64;
    let cores = thread::available_parallelism().map(|c| c.get()).unwrap_or(4) as u64;
    let t = Instant::now();
    let one = count(0..n);
    let single = t.elapsed();

    let t = Instant::now();
    let chunk = n / cores;
    let many: usize = thread::scope(|s| {
        let hs: Vec<_> = (0..cores)
            .map(|i| s.spawn(move || count(i * chunk..if i == cores - 1 { n } else { (i + 1) * chunk })))
            .collect();
        hs.into_iter().map(|h| h.join().unwrap()).sum()
    });
    let multi = t.elapsed();
    println!("{one} primes; same with threads: {}", one == many);
    println!("faster with threads: {}", multi < single);
}
```

*You should see:*

```text
148933 primes; same with threads: true
faster with threads: true
```

*(on an 8-core machine, about 6–7 times faster. Compile with `--release` for real timings)*

For data-parallel loops, the `rayon` crate does the splitting for you: change `.iter()` to
`.par_iter()` and the work is spread over every core — `v.par_iter().map(f).sum()`. The async
world (many network waits, chapter 38's idea) is the `tokio` crate.

## 61.7 common mistakes

**1. `closure may outlive the current function`** — add `move`, or use `thread::scope`.

**2. Forgetting to `join`.** When `main` ends, the program ends — threads still running are
stopped mid-work.

**3. Holding a lock too long.** `let guard = m.lock().unwrap();` keeps the lock until `guard` is
dropped; other threads wait. Lock, change, and let it go — in a small `{ }` block if needed.

**4. Two locks taken in different orders** by two threads can wait for each other forever — a
**deadlock**. Take locks always in the same order, or use one lock, or channels.
