---
id: rs-iter-practice
title: practice
part: rust
chapter: 60
minutes: 18
needs: [rs-own-iter]
optional: no
---

**60.1 ★ Squares.** The squares of 1 to 10, collected into a `Vec`, with `map`.

<!-- solution 60.1 -->
```rust
fn main() {
    let v: Vec<u32> = (1..=10).map(|n| n * n).collect();
    println!("{:?}", v);
}
```

*You should see:*

```text
[1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
```
<!-- /solution -->

**60.2 ★ Evens sum.** The sum of the even numbers from 1 to 100, with `filter` and `sum`.

<!-- solution 60.2 -->
```rust
fn main() {
    println!("{}", (1..=100).filter(|n| n % 2 == 0).sum::<u32>());
}
```

*You should see:*

```text
2550
```
<!-- /solution -->

**60.3 ★ A closure that captures.** `let threshold = 18;` and a closure `is_adult` using it; count adults in `[12, 30, 17, 45]`.

<!-- solution 60.3 -->
```rust
fn main() {
    let threshold = 18;
    let is_adult = |age: &u32| *age >= threshold;
    println!("{}", [12, 30, 17, 45].iter().filter(|a| is_adult(a)).count());
}
```

*You should see:*

```text
2
```
<!-- /solution -->

**60.4 ★★ Word lengths.** From a sentence, a `Vec<(String, usize)>` of each word in capitals with its length.

<!-- solution 60.4 -->
```rust
fn main() {
    let v: Vec<(String, usize)> = "rust is fast".split_whitespace().map(|w| (w.to_uppercase(), w.len())).collect();
    println!("{:?}", v);
}
```

*You should see:*

```text
[("RUST", 4), ("IS", 2), ("FAST", 4)]
```
<!-- /solution -->

**60.5 ★★ Dot product.** `fn dot(a: &[f64], b: &[f64]) -> f64` with `zip`, `map` and `sum`.

<!-- solution 60.5 -->
```rust
fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b).map(|(x, y)| x * y).sum()
}

fn main() {
    println!("{}", dot(&[1.0, 2.0, 3.0], &[4.0, 5.0, 6.0]));
}
```

*You should see:*

```text
32
```
<!-- /solution -->

**60.6 ★★ fold.** The product of 1 to 10 with `fold`, then the longest word of a sentence with `fold`.

<!-- solution 60.6 -->
```rust
fn main() {
    let p = (1..=10u64).fold(1, |acc, n| acc * n);
    let longest = "a borrowed reference lives".split_whitespace().fold("", |best, w| if w.len() > best.len() { w } else { best });
    println!("{p} {longest}");
}
```

*You should see:*

```text
3628800 reference
```
<!-- /solution -->
