---
id: rs-more-tests
title: more kinds of test
part: rust
chapter: 59
minutes: 8
needs: [rs-tests]
optional: no
---

## 59.5 more kinds of test

```rust
fn divide(a: i32, b: i32) -> i32 {
    if b == 0 {
        panic!("division by zero");
    }
    a / b
}

fn parse_age(s: &str) -> Result<u8, String> {
    s.parse::<u8>().map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn divides() {
        assert_eq!(divide(7, 2), 3);
    }

    #[test]
    #[should_panic(expected = "division by zero")]
    fn zero_panics() {
        divide(1, 0);
    }

    #[test]
    fn bad_age_is_an_error() {
        assert!(parse_age("old").is_err());
        assert_eq!(parse_age("42"), Ok(42));
    }

    #[test]
    fn with_question_mark() -> Result<(), String> {
        let a = parse_age("30")?;
        assert!(a > 18, "expected an adult, got {a}");
        Ok(())
    }
}
```

*You should see:*

```text
running 4 tests
test tests::bad_age_is_an_error ... ok
test tests::divides ... ok
test tests::with_question_mark ... ok
test tests::zero_panics - should panic ... ok

test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```

| Write | Checks |
|---|---|
| `assert!(cond)` · `assert!(cond, "msg {x}")` | `cond` is true |
| `assert_eq!(a, b)` · `assert_ne!(a, b)` | equal · different, showing both |
| `#[should_panic(expected = "…")]` | the test panics, with that text |
| a test returning `Result` | fails on `Err` — so `?` works inside |
| `#[ignore]` | skipped unless `cargo test -- --ignored` (slow tests) |

**Integration tests** go in a `tests/` folder beside `src/`: each file there is compiled as a
separate crate that uses your library from outside, as a user would — only its `pub` items.

`textkit/tests/slugs.rs`:

```rust
use textkit::slugify;

#[test]
fn slug_of_a_title() {
    assert_eq!(slugify("Hello, World"), "hello-world");
}
```

```text
$ cd textkit && cargo test -q --test slugs 2>&1 | grep -v '^$'
running 1 test
.
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
```

`cargo test NAME` runs only the tests whose names contain NAME; in neovim, **Space t t** runs a
file's tests and **Space t w** runs them on every save (chapter 48).
