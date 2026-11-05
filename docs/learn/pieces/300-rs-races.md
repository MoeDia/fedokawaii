---
id: rs-races
title: data races are compile errors
part: rust
chapter: 61
minutes: 5
needs: [rs-arc]
optional: no
---

## 61.4 data races are compile errors

Try to share a plain value between threads and change it — the bug that haunts C, C++ and Java
programs for years — and Rust will not compile it:

```rust
use std::thread;

fn main() {
    let mut count = 0;
    let h = thread::spawn(|| {
        count += 1;
    });
    count += 1;
    h.join().unwrap();
}
```

*The compiler says:*

```text
error[E0373]: closure may outlive the current function, but it borrows `count`, which is owned by the current function
 --> src/main.rs:5:27
  |
5 |     let h = thread::spawn(|| {
  |                           ^^ may outlive borrowed value `count`
6 |         count += 1;
  |         ----- `count` is borrowed here
  |
note: function requires argument type to outlive `'static`
 --> src/main.rs:5:13
  |
5 |       let h = thread::spawn(|| {
  |  _____________^
6 | |         count += 1;
7 | |     });
  | |______^
help: to force the closure to take ownership of `count` (and any other referenced variables), use the `move` keyword
  |
5 |     let h = thread::spawn(move || {
  |                           ++++
```

Two traits make this work: `Send` (a value may move to another thread) and `Sync` (it may be
shared between threads). The compiler marks every type automatically, and refuses to send an
`Rc` (non-atomic) or share a `RefCell` across threads. You rarely write them; you meet them in
error messages.
