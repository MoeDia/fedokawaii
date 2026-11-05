---
id: rs-traits-practice
title: practice
part: rust
chapter: 57
minutes: 18
needs: [rs-dyn]
optional: no
---

**57.1 ★ A Greet trait.** `trait Greet { fn hello(&self) -> String; }` for `English` and `Arabic` unit structs; print both.

<!-- solution 57.1 -->
```rust
trait Greet {
    fn hello(&self) -> String;
}

struct English;
struct Arabic;

impl Greet for English {
    fn hello(&self) -> String {
        "hello".into()
    }
}

impl Greet for Arabic {
    fn hello(&self) -> String {
        "marhaba".into()
    }
}

fn main() {
    println!("{} {}", English.hello(), Arabic.hello());
}
```

*You should see:*

```text
hello marhaba
```
<!-- /solution -->

**57.2 ★ Display a point.** `struct Point { x: i32, y: i32 }` printed by `{}` as `(3, 4)`.

<!-- solution 57.2 -->
```rust
use std::fmt;

struct Point {
    x: i32,
    y: i32,
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

fn main() {
    println!("{}", Point { x: 3, y: 4 });
}
```

*You should see:*

```text
(3, 4)
```
<!-- /solution -->

**57.3 ★ Generic smallest.** `fn smallest<T: PartialOrd + Copy>(xs: &[T]) -> T`, tried on ints and chars.

<!-- solution 57.3 -->
```rust
fn smallest<T: PartialOrd + Copy>(xs: &[T]) -> T {
    let mut m = xs[0];
    for &x in xs {
        if x < m {
            m = x;
        }
    }
    m
}

fn main() {
    println!("{} {}", smallest(&[4, 2, 8]), smallest(&['q', 'b', 'z']));
}
```

*You should see:*

```text
2 b
```
<!-- /solution -->

**57.4 ★★ From Celsius.** `struct Celsius(f64)` and `struct Fahrenheit(f64)` with `From<Celsius> for Fahrenheit`; convert 100 °C with `.into()`.

<!-- solution 57.4 -->
```rust
struct Celsius(f64);
struct Fahrenheit(f64);

impl From<Celsius> for Fahrenheit {
    fn from(c: Celsius) -> Self {
        Fahrenheit(c.0 * 9.0 / 5.0 + 32.0)
    }
}

fn main() {
    let f: Fahrenheit = Celsius(100.0).into();
    println!("{}", f.0);
}
```

*You should see:*

```text
212
```
<!-- /solution -->

**57.5 ★★ Default settings.** `#[derive(Default, Debug)]` on a settings struct, but implement `Default` by hand so the font size
starts at 12.

<!-- solution 57.5 -->
```rust
#[derive(Debug)]
struct Settings {
    theme: String,
    font_size: u32,
}

impl Default for Settings {
    fn default() -> Self {
        Settings { theme: "dark".into(), font_size: 12 }
    }
}

fn main() {
    let s = Settings { theme: "light".into(), ..Default::default() };
    println!("{:?} {:?}", Settings::default(), s);
}
```

*You should see:*

```text
Settings { theme: "dark", font_size: 12 } Settings { theme: "light", font_size: 12 }
```
<!-- /solution -->

**57.6 ★★ Sum anything.** `fn total<T: std::iter::Sum<T> + Copy>(xs: &[T]) -> T` with `xs.iter().copied().sum()`, on `i32` and `f64`.

<!-- solution 57.6 -->
```rust
fn total<T: std::iter::Sum<T> + Copy>(xs: &[T]) -> T {
    xs.iter().copied().sum()
}

fn main() {
    println!("{} {}", total(&[1, 2, 3]), total(&[0.5, 0.25]));
}
```

*You should see:*

```text
6 0.75
```
<!-- /solution -->
