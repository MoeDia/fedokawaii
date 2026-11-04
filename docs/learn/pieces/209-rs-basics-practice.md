---
id: rs-basics-practice
title: practice
part: rust
chapter: 49
minutes: 18
needs: [rs-basics-mistakes]
optional: no
---

**49.1 ★ Print it.** Make variables for your name, your city and your age, and print one sentence with all three.

<!-- solution 49.1 -->
```rust
fn main() {
    let name = "Mohamed";
    let city = "Sharjah";
    let age = 34;
    println!("{name} lives in {city} and is {age}.");
}
```

*You should see:*

```text
Mohamed lives in Sharjah and is 34.
```
<!-- /solution -->

**49.2 ★ Seconds.** How many seconds in a week, as a `u32`? And in a century — does it still fit in `u32`? (Try;
then use `u64`.)

<!-- solution 49.2 -->
```rust
fn main() {
    let week: u32 = 7 * 24 * 60 * 60;
    let century: u64 = 100 * 365 * 24 * 60 * 60;
    println!("{week} {century} {}", u32::MAX);
}
```

*You should see:*

```text
604800 3153600000 4294967295
```
<!-- /solution -->

**49.3 ★ Make it change.** Fix this so it compiles and prints 3: `let n = 1; n += 2; println!("{n}");`

<!-- solution 49.3 -->
```rust
fn main() {
    let mut n = 1;
    n += 2;
    println!("{n}");
}
```

*You should see:*

```text
3
```
<!-- /solution -->

**49.4 ★★ Celsius.** `fn to_fahrenheit(c: f64) -> f64`, and print 0, 37 and 100 °C converted, with one decimal
(`{:.1}`).

<!-- solution 49.4 -->
```rust
fn to_fahrenheit(c: f64) -> f64 {
    c * 9.0 / 5.0 + 32.0
}

fn main() {
    for c in [0.0, 37.0, 100.0] {
        println!("{c:.1} °C = {:.1} °F", to_fahrenheit(c));
    }
}
```

*You should see:*

```text
0.0 °C = 32.0 °F
37.0 °C = 98.6 °F
100.0 °C = 212.0 °F
```
<!-- /solution -->

**49.5 ★★ Average of three.** `fn average(a: i32, b: i32, c: i32) -> f64`, returning the exact average (`7, 8, 8` → `7.666…`).

<!-- solution 49.5 -->
```rust
fn average(a: i32, b: i32, c: i32) -> f64 {
    (a + b + c) as f64 / 3.0
}

fn main() {
    println!("{:.3}", average(7, 8, 8));
}
```

*You should see:*

```text
7.667
```
<!-- /solution -->

**49.6 ★★ Swap.** `fn swap(p: (i32, i32)) -> (i32, i32)` returning the pair the other way round.

<!-- solution 49.6 -->
```rust
fn swap(p: (i32, i32)) -> (i32, i32) {
    (p.1, p.0)
}

fn main() {
    println!("{:?}", swap((1, 2)));
}
```

*You should see:*

```text
(2, 1)
```
<!-- /solution -->
