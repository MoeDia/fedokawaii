---
id: rs-take-closures
title: functions that take closures; iterators
part: rust
chapter: 60
minutes: 6
needs: [rs-closures]
optional: no
---

## 60.2 functions that take closures

A function accepts a closure with a generic bound: `Fn` (only reads what it captured), `FnMut`
(changes it), or `FnOnce` (may consume it, so it can be called once):

```rust
fn apply_twice<F: Fn(i32) -> i32>(f: F, x: i32) -> i32 {
    f(f(x))
}

fn repeat(n: usize, mut f: impl FnMut()) {
    for _ in 0..n {
        f();
    }
}

fn main() {
    println!("{}", apply_twice(|x| x + 10, 1));
    println!("{}", apply_twice(|x| x * x, 3));
    let mut log = Vec::new();
    repeat(3, || log.push("tick"));
    println!("{:?}", log);
}
```

*You should see:*

```text
21
81
["tick", "tick", "tick"]
```

## 60.3 iterators

An **iterator** gives values one at a time (chapter 37's Python iterators, exactly). Every
collection makes one with `.iter()`; then **adapters** transform it, and a **consumer** at the end
produces the result:

```rust
fn main() {
    let prices = vec![3.5, 12.0, 7.25, 20.0];
    let total: f64 = prices.iter().sum();
    let cheap: Vec<f64> = prices.iter().filter(|&&p| p < 10.0).cloned().collect();
    let with_vat: Vec<f64> = prices.iter().map(|p| p * 1.05).collect();
    let count = prices.iter().filter(|p| **p > 5.0).count();
    println!("{total} {:?} {:?} {count}", cheap, with_vat);
}
```

*You should see:*

```text
42.75 [3.5, 7.25] [3.6750000000000003, 12.600000000000001, 7.612500000000001, 21.0] 3
```

| Adapter (gives another iterator) | Does |
|---|---|
| `map(f)` | each value changed by `f` |
| `filter(f)` | keeps values where `f` is true |
| `enumerate()` | `(index, value)` |
| `zip(other)` | pairs, side by side |
| `take(n)` · `skip(n)` | the first n · all but the first n |
| `rev()` · `chain(other)` | backwards · one after the other |
| `flat_map(f)` · `flatten()` | each value into many, all joined |
| `take_while(f)` · `skip_while(f)` | while the condition holds |
| `windows(n)` (on slices) · `chunks(n)` | overlapping · separate pieces |

| Consumer (gives a result) | Gives |
|---|---|
| `collect()` | a `Vec`, `String`, `HashMap`, … — whatever type you ask for |
| `sum()` · `product()` · `count()` | a number |
| `min()` · `max()` · `max_by_key(f)` | `Option` of a value |
| `find(f)` · `position(f)` | `Option`: the first match · its index |
| `any(f)` · `all(f)` | `bool` |
| `fold(start, f)` | one value, built step by step |
| `for x in it` | a loop is a consumer too |
