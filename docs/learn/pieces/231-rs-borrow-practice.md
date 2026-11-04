---
id: rs-borrow-practice
title: practice
part: rust
chapter: 52
minutes: 18
needs: [rs-slices]
optional: no
---

**52.1 ★ Borrow to measure.** `fn vowels(s: &str) -> usize`, called twice on the same `String`, which is printed after.

<!-- solution 52.1 -->
```rust
fn vowels(s: &str) -> usize {
    s.chars().filter(|c| "aeiouAEIOU".contains(*c)).count()
}

fn main() {
    let s = String::from("Fedokawaii");
    println!("{} {} {s}", vowels(&s), vowels(&s));
}
```

*You should see:*

```text
6 6 Fedokawaii
```
<!-- /solution -->

**52.2 ★ Change through &mut.** `fn double_all(v: &mut [i32])` doubles every element in place (`for x in v.iter_mut() { *x *= 2 }`).

<!-- solution 52.2 -->
```rust
fn double_all(v: &mut [i32]) {
    for x in v.iter_mut() {
        *x *= 2;
    }
}

fn main() {
    let mut v = vec![1, 2, 3];
    double_all(&mut v);
    println!("{:?}", v);
}
```

*You should see:*

```text
[2, 4, 6]
```
<!-- /solution -->

**52.3 ★ Slice it.** From `"2026-10-21"`, take the year, month and day as `&str` slices.

<!-- solution 52.3 -->
```rust
fn main() {
    let d = "2026-10-21";
    println!("{} {} {}", &d[..4], &d[5..7], &d[8..]);
}
```

*You should see:*

```text
2026 10 21
```
<!-- /solution -->

**52.4 ★★ Fix the order.** Make this compile by moving one line: `let mut v = vec![1]; let r = &v; v.push(2); println!("{:?}", r);`
— so that it prints `[1]`.

<!-- solution 52.4 -->
```rust
fn main() {
    let mut v = vec![1];
    let r = &v;
    println!("{:?}", r);
    v.push(2);
}
```

*You should see:*

```text
[1]
```
<!-- /solution -->

**52.5 ★★ Largest, by reference.** `fn largest(xs: &[i32]) -> &i32` returning a reference to the largest element.

<!-- solution 52.5 -->
```rust
fn largest(xs: &[i32]) -> &i32 {
    let mut best = &xs[0];
    for x in xs {
        if x > best {
            best = x;
        }
    }
    best
}

fn main() {
    let v = vec![3, 9, 2];
    println!("{}", largest(&v));
}
```

*You should see:*

```text
9
```
<!-- /solution -->

**52.6 ★★ Longest without clones.** Rewrite exercise 51.6's `longest` with `&str` parameters — no clones at all. (You will need
`fn longest<'a>(a: &'a str, b: &'a str) -> &'a str`; chapter 58 explains the `'a`.)

<!-- solution 52.6 -->
```rust
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}

fn main() {
    let x = String::from("tea");
    let y = String::from("coffee");
    println!("{} ({x}, {y})", longest(&x, &y));
}
```

*You should see:*

```text
coffee (tea, coffee)
```
<!-- /solution -->
