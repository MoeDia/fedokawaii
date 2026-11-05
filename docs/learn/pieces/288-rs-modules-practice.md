---
id: rs-modules-practice
title: practice
part: rust
chapter: 59
minutes: 13
needs: [rs-crates]
optional: no
---

**59.1 ★ A module.** Put `fn c_to_f` and `fn f_to_c` in `mod temperature` and call both from `main`.

<!-- solution 59.1 -->
```rust
mod temperature {
    pub fn c_to_f(c: f64) -> f64 {
        c * 9.0 / 5.0 + 32.0
    }
    pub fn f_to_c(f: f64) -> f64 {
        (f - 32.0) * 5.0 / 9.0
    }
}

fn main() {
    println!("{} {}", temperature::c_to_f(100.0), temperature::f_to_c(32.0));
}
```

*You should see:*

```text
212 0
```
<!-- /solution -->

**59.2 ★ First tests.** Three `#[test]`s for chapter 50's `is_leap`: 2024, 1900 and 2000.

<!-- solution 59.2 -->
```rust
fn is_leap(y: u32) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn y2024() { assert!(is_leap(2024)); }
    #[test]
    fn y1900() { assert!(!is_leap(1900)); }
    #[test]
    fn y2000() { assert!(is_leap(2000)); }
}
```

*You should see:*

```text
running 3 tests
test tests::y1900 ... ok
test tests::y2000 ... ok
test tests::y2024 ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```
<!-- /solution -->

**59.3 ★ should_panic.** A test that `vec![1, 2][5]` panics, with `expected = "index out of bounds"`.

<!-- solution 59.3 -->
```rust
#[cfg(test)]
mod tests {
    #[test]
    #[should_panic(expected = "index out of bounds")]
    fn out_of_bounds() {
        let v = vec![1, 2];
        let _ = v[5];
    }
}
```

*You should see:*

```text
running 1 test
test tests::out_of_bounds - should panic ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```
<!-- /solution -->

**59.4 ★★ Private by design.** `mod bank` with `pub struct Account { balance: u64 }` (private field), `pub fn new()`,
`pub fn deposit`, `pub fn balance(&self)`. Show from `main` that the balance can only change
through `deposit`.

<!-- solution 59.4 -->
```rust
mod bank {
    pub struct Account {
        balance: u64,
    }
    impl Account {
        pub fn new() -> Self {
            Account { balance: 0 }
        }
        pub fn deposit(&mut self, n: u64) {
            self.balance += n;
        }
        pub fn balance(&self) -> u64 {
            self.balance
        }
    }
}

fn main() {
    let mut a = bank::Account::new();
    a.deposit(40);
    // a.balance = 1_000_000;  // error[E0616]: field `balance` of struct `Account` is private
    println!("{}", a.balance());
}
```

*You should see:*

```text
40
```
<!-- /solution -->

**59.5 ★★ Test the slug.** Add three more tests for `slugify`: an empty title, only punctuation, and kanji (does
`is_alphanumeric` keep them? Find out).

<!-- solution 59.5 -->
```rust
fn slugify(title: &str) -> String {
    title.to_lowercase().split(|c: char| !c.is_alphanumeric()).filter(|w| !w.is_empty()).collect::<Vec<_>>().join("-")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn empty() { assert_eq!(slugify(""), ""); }
    #[test]
    fn only_punctuation() { assert_eq!(slugify("!?,"), ""); }
    #[test]
    fn kanji_are_kept() { assert_eq!(slugify("京都 Trip"), "京都-trip"); }
}
```

*You should see:*

```text
running 3 tests
test tests::empty ... ok
test tests::kanji_are_kept ... ok
test tests::only_punctuation ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```
<!-- /solution -->
