---
id: rs-slices
title: slices; common mistakes
part: rust
chapter: 52
minutes: 8
needs: [rs-dangling]
optional: no
---

## 52.6 slices: borrowing a part

A **slice** borrows a stretch of a string or array: `&s[start..end]`. The string slice type is
`&str` — which is what text literals have been all along:

```rust
fn main() {
    let s = String::from("hello world");
    let hello: &str = &s[0..5];
    let world = &s[6..];
    println!("[{hello}] [{world}]");

    let nums = [10, 20, 30, 40, 50];
    let middle: &[i32] = &nums[1..4];
    println!("{:?} {}", middle, middle.len());
}
```

*You should see:*

```text
[hello] [world]
[20, 30, 40] 3
```

A function that takes `&[i32]` works with arrays, `Vec`s and parts of either:

```rust
fn sum(xs: &[i32]) -> i32 {
    let mut total = 0;
    for x in xs {
        total += x;
    }
    total
}

fn main() {
    let arr = [1, 2, 3, 4];
    let v = vec![10, 20, 30];
    println!("{} {} {}", sum(&arr), sum(&v), sum(&arr[..2]));
}
```

*You should see:*

```text
10 60 3
```

The first word of a sentence, returned as a slice of it — no copying:

```rust
fn first_word(s: &str) -> &str {
    match s.find(' ') {
        Some(i) => &s[..i],
        None => s,
    }
}

fn main() {
    let text = String::from("borrow checker");
    println!("{}", first_word(&text));
    println!("{}", first_word("single"));
}
```

*You should see:*

```text
borrow
single
```

> **Careful.** String slices count **bytes**, not letters. Non-English letters take 2–4 bytes;
> slicing through the middle of one panics. For letters, use `.chars()`.

```rust
fn main() {
    let s = "京都";
    println!("{} bytes, {} letters", s.len(), s.chars().count());
    println!("{}", &s[0..1]);
}
```

*You should see:*

```text
6 bytes, 2 letters

thread 'main' (1) panicked at src/main.rs:4:22:
end byte index 1 is not a char boundary; it is inside '京' (bytes 0..3 of string)
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

## 52.7 common mistakes

**1. `cannot borrow as mutable more than once`** (E0499) or `… as mutable because it is also
borrowed as immutable` (E0502). Finish with one borrow before starting the other: often
just reorder lines, or put one use in its own `{ }` block.

**2. Taking `&String` or `&Vec<T>` parameters.** Take `&str` and `&[T]`: they accept more.

**3. Returning a reference to something made inside the function.** Return the owned value.
