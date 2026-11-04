---
id: rs-threads-practice
title: practice
part: rust
chapter: 61
minutes: 12
needs: [rs-scanner]
optional: no
---

**61.1 ★ Two threads.** Spawn two threads that each return a string; `join` both and print them.

<!-- solution 61.1 -->
```rust
use std::thread;

fn main() {
    let a = thread::spawn(|| String::from("from a"));
    let b = thread::spawn(|| String::from("from b"));
    println!("{} {}", a.join().unwrap(), b.join().unwrap());
}
```

*You should see:*

```text
from a from b
```
<!-- /solution -->

**61.2 ★ Move a Vec.** Move a `Vec<i32>` into a thread that returns its sum.

<!-- solution 61.2 -->
```rust
use std::thread;

fn main() {
    let v = vec![1, 2, 3, 4];
    let h = thread::spawn(move || v.iter().sum::<i32>());
    println!("{}", h.join().unwrap());
}
```

*You should see:*

```text
10
```
<!-- /solution -->

**61.3 ★★ Scoped halves.** With `thread::scope`, find the max of each half of a slice in two threads, then the overall max.

<!-- solution 61.3 -->
```rust
use std::thread;

fn main() {
    let data = [3, 17, 8, 42, 5, 23, 9, 1];
    let (l, r) = data.split_at(4);
    let m = thread::scope(|s| {
        let a = s.spawn(|| *l.iter().max().unwrap());
        let b = s.spawn(|| *r.iter().max().unwrap());
        a.join().unwrap().max(b.join().unwrap())
    });
    println!("{m}");
}
```

*You should see:*

```text
42
```
<!-- /solution -->

**61.4 ★★ A shared list.** Four threads each push their id into an `Arc<Mutex<Vec<u32>>>`; print the sorted list.

<!-- solution 61.4 -->
```rust
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    let list = Arc::new(Mutex::new(Vec::new()));
    let hs: Vec<_> = (0..4)
        .map(|i| {
            let l = Arc::clone(&list);
            thread::spawn(move || l.lock().unwrap().push(i))
        })
        .collect();
    for h in hs {
        h.join().unwrap();
    }
    let mut v = list.lock().unwrap().clone();
    v.sort();
    println!("{:?}", v);
}
```

*You should see:*

```text
[0, 1, 2, 3]
```
<!-- /solution -->
