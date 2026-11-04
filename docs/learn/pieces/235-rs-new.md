---
id: rs-new
title: associated functions: new
part: rust
chapter: 53
minutes: 4
needs: [rs-methods]
optional: no
---

## 53.4 associated functions: new

A function in `impl` *without* `self` belongs to the type, not a value — called with `::`. The
habit is a `new` that builds one, checking what must be true:

```rust
#[derive(Debug)]
struct Temperature {
    celsius: f64,
}

impl Temperature {
    fn new(celsius: f64) -> Temperature {
        assert!(celsius >= -273.15, "below absolute zero");
        Temperature { celsius }
    }

    fn from_fahrenheit(f: f64) -> Self {
        Self::new((f - 32.0) * 5.0 / 9.0)
    }

    fn fahrenheit(&self) -> f64 {
        self.celsius * 9.0 / 5.0 + 32.0
    }
}

fn main() {
    let t = Temperature::new(31.0);
    let u = Temperature::from_fahrenheit(212.0);
    println!("{:.1} {:?}", t.fahrenheit(), u);
}
```

*You should see:*

```text
87.8 Temperature { celsius: 100.0 }
```

*(`Self` inside an `impl` means the type itself, here `Temperature`. `String::from` and
`Vec::new` are associated functions too)*
