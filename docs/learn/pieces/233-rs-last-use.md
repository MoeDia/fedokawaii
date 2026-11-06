---
id: rs-last-use
title: a borrow ends at its last use
part: rust
chapter: 52
minutes: 4
needs: [rs-rule]
optional: no
---

## 52.4 a borrow ends at its last use

A reference counts as "alive" only up to the last line that uses it — not to the end of the
block. So this compiles: the readers are done before the writer starts.

```rust
fn main() {
    let mut s = String::from("hi");
    let r1 = &s;
    let r2 = &s;
    println!("{r1} {r2}");
    let w = &mut s;
    w.push('!');
    println!("{s}");
}
```

*You should see:*

```text
hi hi
hi!
```

The classic trap — growing a list while holding a reference into it:

```rust
fn main() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];
    v.push(4);
    println!("{first}");
}
```

*The compiler says:*

```text
error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable
 --> src/main.rs:4:5
  |
3 |     let first = &v[0];
  |                  - immutable borrow occurs here
4 |     v.push(4);
  |     ^^^^^^^^^ mutable borrow occurs here
5 |     println!("{first}");
  |                ----- immutable borrow later used here
```

*(why it matters: `push` may move the whole list to a bigger place in memory, and `first` would
point at the old, freed place. In C that is a crash; in Rust, a compile error)*
