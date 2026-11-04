---
id: rs-basics-projects
title: projects
part: rust
chapter: 49
minutes: 180
needs: [rs-basics-practice]
optional: yes
---

**49.7 ★★★ Seconds to time.** `fn hms(total: u32) -> (u32, u32, u32)`: hours, minutes and seconds; print 3725 as `01:02:05`
(`{:02}` pads with zeros).

<!-- solution 49.7 -->
```rust
fn hms(total: u32) -> (u32, u32, u32) {
    (total / 3600, total % 3600 / 60, total % 60)
}

fn main() {
    let (h, m, s) = hms(3725);
    println!("{h:02}:{m:02}:{s:02}");
}
```

*You should see:*

```text
01:02:05
```
<!-- /solution -->

**49.8 ★★★ Find the overflow.** What is the largest `n` for which `n * n` fits in an `i32`? Find it with `i32::MAX` and
`f64::sqrt`, then check that `(n + 1).checked_mul(n + 1)` is `None`.

<!-- solution 49.8 -->
```rust
fn main() {
    let n = (i32::MAX as f64).sqrt() as i32;
    println!("{n} {:?} {:?}", n.checked_mul(n), (n + 1).checked_mul(n + 1));
}
```

*You should see:*

```text
46340 Some(2147395600) None
```
<!-- /solution -->

**49.9 ★★★★ Body mass index, with a verdict.** `fn bmi(kg: f64, m: f64) -> f64` and `fn verdict(bmi: f64) -> &'static str` (under 18.5 *under*,
under 25 *normal*, under 30 *over*, else *obese* — use `if`/`else if` as an expression, chapter
50 shows them; try it). Print three people in an aligned table (`{:<8}`, `{:>6.1}`).

<!-- solution 49.9 -->
```rust
fn bmi(kg: f64, m: f64) -> f64 {
    kg / (m * m)
}

fn verdict(b: f64) -> &'static str {
    if b < 18.5 {
        "under"
    } else if b < 25.0 {
        "normal"
    } else if b < 30.0 {
        "over"
    } else {
        "obese"
    }
}

fn main() {
    for (name, kg, m) in [("Sara", 55.0, 1.68), ("Omar", 92.0, 1.75), ("Lina", 48.0, 1.70)] {
        let b = bmi(kg, m);
        println!("{name:<8}{b:>6.1}  {}", verdict(b));
    }
}
```

*You should see:*

```text
Sara      19.5  normal
Omar      30.0  obese
Lina      16.6  under
```
<!-- /solution -->
