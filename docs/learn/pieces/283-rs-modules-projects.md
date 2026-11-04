---
id: rs-modules-projects
title: projects
part: rust
chapter: 59
minutes: 150
needs: [rs-modules-practice]
optional: yes
---

**59.6 ★★★ A library crate.** `cargo new --lib units` with `pub fn km_to_miles`, `pub fn miles_to_km`, a doc test on each, unit
tests that one undoes the other (within `1e-9`), and a `tests/` integration test. `cargo test`
should report all three kinds.

<!-- solution 59.6 -->
```rust
// src/lib.rs
/// ```
/// assert!((units::km_to_miles(1.609344) - 1.0).abs() < 1e-9);
/// ```
pub fn km_to_miles(km: f64) -> f64 { km / 1.609344 }

/// ```
/// assert_eq!(units::miles_to_km(1.0), 1.609344);
/// ```
pub fn miles_to_km(mi: f64) -> f64 { mi * 1.609344 }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn round_trip() {
        for x in [0.0, 1.0, 42.195, 1e6] {
            assert!((miles_to_km(km_to_miles(x)) - x).abs() < 1e-9);
        }
    }
}

// tests/marathon.rs
#[test]
fn marathon() {
    assert!((units::km_to_miles(42.195) - 26.2188).abs() < 1e-3);
}
```
*(cargo test prints three sections: `unittests src/lib.rs` 1 passed, `tests/marathon.rs` 1
passed, `Doc-tests units` 2 passed)*
<!-- /solution -->

**59.7 ★★★★ The expense ledger, in Rust.** Port level 3's Python `ledger.py` (chapter 33) to a Rust library: `struct Row { date: String,
category: String, amount: f64 }`, `fn parse(line: &str) -> Result<Row, String>`,
`fn totals(rows: &[Row]) -> BTreeMap<String, f64>`, `load` and `save` with `std::fs`, each with
tests; then a thin `main.rs` reading commands. Compare the two versions: length, and what each
compiler or checker caught.

<!-- solution 59.7 -->
```rust
use std::collections::BTreeMap;

#[derive(Debug, PartialEq)]
pub struct Row {
    pub date: String,
    pub category: String,
    pub amount: f64,
}

pub fn parse(line: &str) -> Result<Row, String> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    let [date, category, amount] = parts.as_slice() else {
        return Err("write: DATE CATEGORY AMOUNT".into());
    };
    let amount = amount.parse::<f64>().map_err(|e| format!("amount: {e}"))?;
    Ok(Row { date: date.to_string(), category: category.to_string(), amount })
}

pub fn totals(rows: &[Row]) -> BTreeMap<String, f64> {
    let mut t = BTreeMap::new();
    for r in rows {
        *t.entry(r.category.clone()).or_insert(0.0) += r.amount;
    }
    t
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses() {
        assert_eq!(parse("2026-10-21 food 32.5").unwrap().amount, 32.5);
    }
    #[test]
    fn refuses() {
        assert!(parse("lunch").is_err());
        assert!(parse("d food x").is_err());
    }
    #[test]
    fn totals_by_category() {
        let rows = vec![parse("d food 1").unwrap(), parse("d food 2").unwrap(), parse("d taxi 5").unwrap()];
        let t = totals(&rows);
        assert_eq!(t["food"], 3.0);
        assert_eq!(t["taxi"], 5.0);
    }
}
```

*You should see:*

```text
running 3 tests
test tests::parses ... ok
test tests::refuses ... ok
test tests::totals_by_category ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```
<!-- /solution -->
