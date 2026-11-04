---
id: rs-arc
title: Arc and Mutex
part: rust
chapter: 61
minutes: 4
needs: [rs-why-move]
optional: no
---

## 61.3 sharing state: Arc and Mutex

Several threads changing one value must take turns. A **Mutex** (*mutual exclusion*) lets one
thread at a time `lock` the value; an **Arc** (*atomically reference-counted*) lets several
threads own the same mutex:

```rust
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    let counter = Arc::new(Mutex::new(0));
    let mut handles = vec![];
    for _ in 0..8 {
        let c = Arc::clone(&counter);
        handles.push(thread::spawn(move || {
            for _ in 0..1000 {
                *c.lock().unwrap() += 1;
            }
        }));
    }
    for h in handles {
        h.join().unwrap();
    }
    println!("{}", *counter.lock().unwrap());
}
```

*You should see:*

```text
8000
```

*(8 threads × 1000 = 8000, every time. The lock is released at the end of each statement, when
the guard `lock()` gave back is dropped)*

| Type | Gives |
|---|---|
| `Arc<T>` | shared ownership across threads (read-only by itself) |
| `Mutex<T>` | one thread at a time may change `T` |
| `RwLock<T>` | many readers or one writer — chapter 52's rule, at run time |
| `AtomicU64` etc. | a single number changed safely without a lock |
