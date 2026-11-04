---
id: rs-lib-bin
title: a library and a binary
part: rust
chapter: 59
minutes: 7
needs: [rs-module-files]
optional: no
---

## 59.3 a library and a binary

A package can hold a **library** (`src/lib.rs`: code for others — and for your tests) and a
**binary** (`src/main.rs`: the program). Put the logic in the library and keep `main.rs` thin; then
everything is testable:

```text
$ cargo new -q --lib textkit
```

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_words() {
        assert_eq!(word_count("a b c"), 3);
    }

    #[test]
    fn empty_has_no_words() {
        assert_eq!(word_count("   "), 0);
    }

    #[test]
    fn slug_drops_punctuation() {
        assert_eq!(slugify("Rust, Python & AI!"), "rust-python-ai");
    }
}
```

`textkit/src/main.rs`:

```rust
fn main() {
    let title = "Ownership, Borrowing & Lifetimes";
    println!("{} words → {}", textkit::word_count(title), textkit::slugify(title));
}
```

```text
$ cd textkit && cargo run -q
4 words → ownership-borrowing-lifetimes
```
