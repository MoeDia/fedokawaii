---
id: rs-why-move
title: why move
part: rust
chapter: 61
minutes: 6
needs: [rs-threads-start]
optional: no
---

## 61.2 why move

A spawned thread may outlive the function that started it, so it cannot borrow that function's
variables — the compiler refuses:

```rust
use std::thread;

fn main() {
    let name = String::from("Sara");
    let h = thread::spawn(|| {
        println!("hello {name}");
    });
    h.join().unwrap();
}
```

*The compiler says:*

```text
error[E0373]: closure may outlive the current function, but it borrows `name`, which is owned by the current function
 --> src/main.rs:5:27
  |
5 |     let h = thread::spawn(|| {
  |                           ^^ may outlive borrowed value `name`
6 |         println!("hello {name}");
  |                          ---- `name` is borrowed here
  |
note: function requires argument type to outlive `'static`
 --> src/main.rs:5:13
  |
5 |       let h = thread::spawn(|| {
  |  _____________^
6 | |         println!("hello {name}");
7 | |     });
  | |______^
help: to force the closure to take ownership of `name` (and any other referenced variables), use the `move` keyword
  |
5 |     let h = thread::spawn(move || {
  |                           ++++
```

`move` hands the closure ownership; or use **scoped threads**, which are guaranteed to finish
before the scope ends — and so may borrow:

```rust
use std::thread;

fn main() {
    let data = vec![1, 2, 3, 4, 5, 6, 7, 8];
    let (left, right) = data.split_at(data.len() / 2);
    let (a, b) = thread::scope(|s| {
        let ha = s.spawn(|| left.iter().sum::<i32>());
        let hb = s.spawn(|| right.iter().sum::<i32>());
        (ha.join().unwrap(), hb.join().unwrap())
    });
    println!("{a} + {b} = {}", a + b);
    println!("data is still mine: {:?}", data);
}
```

*You should see:*

```text
10 + 26 = 36
data is still mine: [1, 2, 3, 4, 5, 6, 7, 8]
```
