---
id: rs-threads-projects
title: projects
part: rust
chapter: 61
minutes: 180
needs: [rs-threads-practice]
optional: yes
---

**61.5 ★★★ Workers and a channel.** Three worker threads take numbers from a shared job channel (`Arc<Mutex<Receiver<u64>>>`), square
them, and send results back on a second channel; feed them 1–9 and print the sum.

<!-- solution 61.5 -->
```rust
use std::sync::{mpsc, Arc, Mutex};
use std::thread;

fn main() {
    let (job_tx, job_rx) = mpsc::channel::<u64>();
    let (res_tx, res_rx) = mpsc::channel::<u64>();
    let job_rx = Arc::new(Mutex::new(job_rx));
    let mut workers = Vec::new();
    for _ in 0..3 {
        let rx = Arc::clone(&job_rx);
        let tx = res_tx.clone();
        workers.push(thread::spawn(move || {
            loop {
                let job = rx.lock().unwrap().recv();
                match job {
                    Ok(n) => tx.send(n * n).unwrap(),
                    Err(_) => break,
                }
            }
        }));
    }
    drop(res_tx);
    for n in 1..=9 {
        job_tx.send(n).unwrap();
    }
    drop(job_tx);
    for w in workers {
        w.join().unwrap();
    }
    println!("{}", res_rx.iter().sum::<u64>());
}
```

*You should see:*

```text
285
```
<!-- /solution -->

**61.6 ★★★ An atomic counter.** Redo the 8-thread counter with `std::sync::atomic::AtomicU64` (`fetch_add(1, Ordering::Relaxed)`)
instead of a `Mutex`.

<!-- solution 61.6 -->
```rust
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;

fn main() {
    let c = Arc::new(AtomicU64::new(0));
    let hs: Vec<_> = (0..8)
        .map(|_| {
            let c = Arc::clone(&c);
            thread::spawn(move || {
                for _ in 0..1000 {
                    c.fetch_add(1, Ordering::Relaxed);
                }
            })
        })
        .collect();
    for h in hs {
        h.join().unwrap();
    }
    println!("{}", c.load(Ordering::Relaxed));
}
```

*You should see:*

```text
8000
```
<!-- /solution -->

**61.7 ★★★★ Parallel Monte Carlo.** Estimate π by throwing random points in a square and counting those inside the circle — 8 threads,
10 million points in all, each thread with its own simple random generator (an *xorshift*:
`x ^= x << 13; x ^= x >> 7; x ^= x << 17;` on a `u64`, seeded differently per thread). Print the
estimate to 3 places.

<!-- solution 61.7 -->
```rust
use std::thread;

fn xorshift(x: &mut u64) -> f64 {
    *x ^= *x << 13;
    *x ^= *x >> 7;
    *x ^= *x << 17;
    (*x >> 11) as f64 / (1u64 << 53) as f64
}

fn main() {
    let per = 10_000_000 / 8;
    let inside: u64 = thread::scope(|s| {
        let hs: Vec<_> = (0..8u64)
            .map(|t| {
                s.spawn(move || {
                    let mut seed = 0x9E3779B97F4A7C15 ^ (t + 1).wrapping_mul(0xBF58476D1CE4E5B9);
                    let mut hits = 0;
                    for _ in 0..per {
                        let (x, y) = (xorshift(&mut seed), xorshift(&mut seed));
                        if x * x + y * y <= 1.0 {
                            hits += 1;
                        }
                    }
                    hits
                })
            })
            .collect();
        hs.into_iter().map(|h| h.join().unwrap()).sum()
    });
    println!("{:.3}", 4.0 * inside as f64 / (per * 8) as f64);
}
```

*You should see:*

```text
3.141
```
<!-- /solution -->
