---
id: rs-threads-start
title: threads
part: rust
chapter: 61
minutes: 5
needs: [rs-iter-practice]
optional: no
---

> **In this chapter**
>
> - threads: several things at once, on several cores
> - `move` closures and `join`; scoped threads
> - sharing safely: `Arc` and `Mutex`; sending messages with channels
> - why Rust's compiler makes data races impossible
> - the checkpoint for level 5: a parallel file scanner

## 61.1 threads

Your processor has many cores; a normal program uses one. A **thread** is a second line of work
inside the same program, running at the same time on another core. `std::thread::spawn` starts
one with a closure; `join` waits for it to finish and hands back its result:

```rust
use std::thread;

fn main() {
    let handle = thread::spawn(|| {
        let mut sum = 0u64;
        for i in 0..1_000_000 {
            sum += i;
        }
        sum
    });
    println!("the main thread goes on meanwhile");
    let result = handle.join().unwrap();
    println!("the thread computed {result}");
}
```

*You should see:*

```text
the main thread goes on meanwhile
the thread computed 499999500000
```

Several threads, each with its own part of the work. `move` gives each closure its own copy of
`i`:

```rust
use std::thread;

fn main() {
    let mut handles = Vec::new();
    for i in 0..4 {
        handles.push(thread::spawn(move || {
            let start = i * 250;
            (start..start + 250).map(|n: u64| n * n).sum::<u64>()
        }));
    }
    let total: u64 = handles.into_iter().map(|h| h.join().unwrap()).sum();
    println!("{total}");
    println!("{}", (0..1000u64).map(|n| n * n).sum::<u64>());
}
```

*You should see:*

```text
332833500
332833500
```

*(the order threads run in is up to the system. The *results* are the same every time; only
prints from inside threads may interleave differently)*
