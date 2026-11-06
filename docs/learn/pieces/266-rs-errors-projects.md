---
id: rs-errors-projects
title: projects
part: rust
chapter: 56
minutes: 180
needs: [rs-errors-practice]
optional: yes
---

**56.7 ★★★ A validated age.** `struct Age(u8)` with `fn new(n: i32) -> Result<Age, AgeError>` where `enum AgeError { Negative, TooOld }`
with a `Display`. Try -3, 40 and 200.

<!-- solution 56.7 -->
```rust
use std::fmt;

#[derive(Debug)]
struct Age(u8);

#[derive(Debug)]
enum AgeError {
    Negative,
    TooOld,
}

impl fmt::Display for AgeError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            AgeError::Negative => write!(f, "an age cannot be negative"),
            AgeError::TooOld => write!(f, "an age must be under 150"),
        }
    }
}

impl Age {
    fn new(n: i32) -> Result<Age, AgeError> {
        match n {
            ..0 => Err(AgeError::Negative),
            0..150 => Ok(Age(n as u8)),
            _ => Err(AgeError::TooOld),
        }
    }
}

fn main() {
    for n in [-3, 40, 200] {
        match Age::new(n) {
            Ok(a) => println!("{n}: {:?}", a),
            Err(e) => println!("{n}: {e}"),
        }
    }
}
```

*You should see:*

```text
-3: an age cannot be negative
40: Age(40)
200: an age must be under 150
```
<!-- /solution -->

**56.8 ★★★ CSV sums, with line numbers.** Read a small CSV `name,amount` (write it first), sum the amounts, and on a bad line return an
error saying which line and why.

<!-- solution 56.8 -->
```rust
use std::fs;

fn total(path: &str) -> Result<f64, String> {
    let text = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let mut sum = 0.0;
    for (i, line) in text.lines().enumerate().skip(1) {
        let (_, amount) = line.split_once(',').ok_or(format!("line {}: no comma", i + 1))?;
        sum += amount.trim().parse::<f64>().map_err(|e| format!("line {}: {e}", i + 1))?;
    }
    Ok(sum)
}

fn main() {
    fs::write("a.csv", "name,amount\ntea,12.5\nrice,7.25\n").unwrap();
    fs::write("b.csv", "name,amount\ntea,12.5\nrice,lots\n").unwrap();
    println!("{:?}\n{:?}", total("a.csv"), total("b.csv"));
}
```

*You should see:*

```text
Ok(19.75)
Err("line 3: invalid float literal")
```
<!-- /solution -->

**56.9 ★★★★ A key-value store on disk.** `struct Store { path: String, data: BTreeMap<String, String> }` with `open(path) -> Result<Store, …>`
(a missing file means empty), `get`, `set`, `remove`, and `save(&self) -> Result<(), …>` writing
`key=value` lines; a bad line in the file is an error naming the line. Round-trip it.

<!-- solution 56.9 -->
```rust
use std::collections::BTreeMap;
use std::error::Error;
use std::fs;
use std::io::ErrorKind;

struct Store {
    path: String,
    data: BTreeMap<String, String>,
}

impl Store {
    fn open(path: &str) -> Result<Store, Box<dyn Error>> {
        let text = match fs::read_to_string(path) {
            Ok(t) => t,
            Err(e) if e.kind() == ErrorKind::NotFound => String::new(),
            Err(e) => return Err(e.into()),
        };
        let mut data = BTreeMap::new();
        for (i, line) in text.lines().enumerate() {
            let (k, v) = line.split_once('=').ok_or(format!("{path}:{}: no '='", i + 1))?;
            data.insert(k.to_string(), v.to_string());
        }
        Ok(Store { path: path.to_string(), data })
    }
    fn get(&self, k: &str) -> Option<&String> {
        self.data.get(k)
    }
    fn set(&mut self, k: &str, v: &str) {
        self.data.insert(k.into(), v.into());
    }
    fn remove(&mut self, k: &str) -> Option<String> {
        self.data.remove(k)
    }
    fn save(&self) -> Result<(), Box<dyn Error>> {
        let text: String = self.data.iter().map(|(k, v)| format!("{k}={v}\n")).collect();
        fs::write(&self.path, text)?;
        Ok(())
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let _ = fs::remove_file("kv.txt");
    let mut s = Store::open("kv.txt")?;
    s.set("theme", "dark");
    s.set("font", "12");
    s.set("tmp", "x");
    s.remove("tmp");
    s.save()?;
    let again = Store::open("kv.txt")?;
    println!("{:?} {:?}", again.get("theme"), again.data);
    fs::write("broken.txt", "ok=1\nbroken\n")?;
    if let Err(e) = Store::open("broken.txt") {
        println!("error: {e}");
    }
    Ok(())
}
```

*You should see:*

```text
Some("dark") {"font": "12", "theme": "dark"}
error: broken.txt:2: no '='
```
<!-- /solution -->
