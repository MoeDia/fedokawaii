---
id: rs-basics-mistakes
title: common mistakes
part: rust
chapter: 49
minutes: 2
needs: [rs-expressions]
optional: no
---

## 49.8 common mistakes

**1. Forgetting `mut`.** `cannot assign twice to immutable variable` — add `mut` where the
compiler points.

**2. Mixing number types.** `cannot add a float to an integer` — convert with `as`, or write the
literal with a point (`2.0`, not `2`).

**3. A `;` after the last expression.** `mismatched types … expected i32, found ()` — remove it.

**4. Single quotes for text.** `'hello'` is an error: single quotes hold one `char`. Text is in
double quotes.

```rust
fn main() {
    let s = 'hello';
}
```

*The compiler says:*

```text
error: character literal may only contain one codepoint
 --> src/main.rs:2:13
  |
2 |     let s = 'hello';
  |             ^^^^^^^
  |
help: if you meant to write a string literal, use double quotes
  |
2 -     let s = 'hello';
2 +     let s = "hello";
  |
```
