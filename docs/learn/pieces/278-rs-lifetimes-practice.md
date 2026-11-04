---
id: rs-lifetimes-practice
title: practice
part: rust
chapter: 58
minutes: 12
needs: [rs-statistics]
optional: no
---

**58.1 ★ Which need 'a?.** Without compiling, say which of these need a lifetime written: (a) `fn f(s: &str) -> &str`,
(b) `fn g(a: &str, b: &str) -> String`, (c) `fn h(a: &str, b: &str) -> &str`,
(d) `fn m(&self, other: &str) -> &str` in an `impl`.

<!-- solution 58.1 -->
Only (c). (a) has one input reference; (b) returns an owned `String`; (d) returns a borrow
of `self` by the method rule. In (c), write `fn h<'a>(a: &'a str, b: &'a str) -> &'a str` — or
tie the result to only the one it really comes from.
<!-- /solution -->

**58.2 ★ First line.** `fn first_line(text: &str) -> &str` (no `'a` needed). Try it on a two-line string.

<!-- solution 58.2 -->
```rust
fn first_line(text: &str) -> &str {
    text.lines().next().unwrap_or("")
}

fn main() {
    println!("{}", first_line("one\ntwo"));
}
```

*You should see:*

```text
one
```
<!-- /solution -->

**58.3 ★★ Pick by flag.** `fn pick<'a>(a: &'a str, b: &'a str, first: bool) -> &'a str`.

<!-- solution 58.3 -->
```rust
fn pick<'a>(a: &'a str, b: &'a str, first: bool) -> &'a str {
    if first { a } else { b }
}

fn main() {
    println!("{} {}", pick("x", "y", true), pick("x", "y", false));
}
```

*You should see:*

```text
x y
```
<!-- /solution -->

**58.4 ★★ Only one input matters.** `fn prefix_of<'a>(text: &'a str, sep: &str) -> &'a str` returning the part before `sep` — note
`sep` gets no `'a`. Show it compiles when `sep` is dropped before the result is used.

<!-- solution 58.4 -->
```rust
fn prefix_of<'a>(text: &'a str, sep: &str) -> &'a str {
    text.split(sep).next().unwrap_or(text)
}

fn main() {
    let text = String::from("key=value");
    let p;
    {
        let sep = String::from("=");
        p = prefix_of(&text, &sep);
    }
    println!("{p}");
}
```

*You should see:*

```text
key
```
<!-- /solution -->
