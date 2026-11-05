---
id: rs-into-iter
title: iter, iter_mut, into_iter; laziness
part: rust
chapter: 60
minutes: 4
needs: [rs-take-closures]
optional: no
---

## 60.4 iter, iter_mut, into_iter

Three ways in, by what each value should be — the same choice as chapter 55's loops:

```rust
fn main() {
    let mut v = vec![1, 2, 3];
    let doubled: Vec<i32> = v.iter().map(|x| x * 2).collect();
    for x in v.iter_mut() {
        *x += 100;
    }
    let owned: Vec<String> = v.into_iter().map(|x| x.to_string()).collect();
    println!("{:?} {:?}", doubled, owned);
}
```

*You should see:*

```text
[2, 4, 6] ["101", "102", "103"]
```

## 60.5 laziness

Adapters do nothing by themselves: they describe work. Only a consumer makes values flow — and
then one value at a time goes through the whole chain:

```rust
fn main() {
    let it = (1..=3).map(|x| {
        println!("  map {x}");
        x * 10
    });
    println!("nothing has run yet");
    let v: Vec<i32> = it.collect();
    println!("{:?}", v);

    let first_big = (1..).map(|n| n * n).find(|&sq| sq > 50);
    println!("{:?}", first_big);
}
```

*You should see:*

```text
nothing has run yet
  map 1
  map 2
  map 3
[10, 20, 30]
Some(64)
```

*(`1..` has no end — an infinite range — but `find` stops at the first match, so only 8 squares
are ever made)*
