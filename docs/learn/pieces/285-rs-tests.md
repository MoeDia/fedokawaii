---
id: rs-tests
title: tests
part: rust
chapter: 59
minutes: 8
needs: [rs-lib-bin]
optional: no
---

## 59.4 tests

`#[cfg(test)] mod tests` holds tests that are compiled only for `cargo test`. Each `#[test]`
function is one test; `assert_eq!(left, right)` checks two values are equal, and shows both when
they are not:

```text
$ cd textkit && cargo test -q 2>&1 | grep -v '^$'
running 3 tests
...
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
running 0 tests
test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
running 1 test
.
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
all doctests ran in 0.01s; merged doctests compilation took 0.18s
```

*(three unit tests, then the **doc test**: the example in `word_count`'s documentation is
compiled and run too — so examples in docs can never go stale)*

A failing test shows both sides, like pytest:

`textkit/src/lib.rs`:

```rust
pub fn word_count(text: &str) -> usize {
    text.split(' ').count()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_has_no_words() {
        assert_eq!(word_count("   "), 0);
    }
}
```

```text
$ cd textkit && cargo test -q --lib 2>&1 | grep -v '^$'
running 1 test
tests::empty_has_no_words --- FAILED
failures:
---- tests::empty_has_no_words stdout ----
thread 'tests::empty_has_no_words' (1) panicked at src/lib.rs:11:9:
assertion `left == right` failed
  left: 4
 right: 0
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
failures:
    tests::empty_has_no_words
test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
error: test failed, to rerun pass `--lib`
```

*(`split(' ')` makes a piece between every two spaces: four empty pieces. `split_whitespace` is
the fix — put the first version back)*

`textkit/src/lib.rs`:

```rust
//! Small text tools.

/// Counts the words in `text`.
///
/// ```
/// assert_eq!(textkit::word_count("one two  three"), 3);
/// ```
pub fn word_count(text: &str) -> usize {
    text.split_whitespace().count()
}

/// Turns a title into a URL slug: `"Hello, World"` → `"hello-world"`.
pub fn slugify(title: &str) -> String {
    title
        .to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}
```
