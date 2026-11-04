---
id: rs-borrow-projects
title: projects
part: rust
chapter: 52
minutes: 180
needs: [rs-borrow-practice]
optional: yes
---

**52.7 ★★★ Split in two.** `fn split_at_comma(s: &str) -> (&str, &str)` returning the parts before and after the first
comma (trimmed), or `(s, "")` if there is none.

<!-- solution 52.7 -->
```rust
fn split_at_comma(s: &str) -> (&str, &str) {
    match s.find(',') {
        Some(i) => (s[..i].trim(), s[i + 1..].trim()),
        None => (s, ""),
    }
}

fn main() {
    println!("{:?} {:?}", split_at_comma("Sara, Sharjah"), split_at_comma("alone"));
}
```

*You should see:*

```text
("Sara", "Sharjah") ("alone", "")
```
<!-- /solution -->

**52.8 ★★★ Reverse in place.** `fn reverse(v: &mut [i32])` with two indexes walking inwards and `v.swap(i, j)`.

<!-- solution 52.8 -->
```rust
fn reverse(v: &mut [i32]) {
    if v.is_empty() {
        return;
    }
    let (mut i, mut j) = (0, v.len() - 1);
    while i < j {
        v.swap(i, j);
        i += 1;
        j -= 1;
    }
}

fn main() {
    let mut v = [1, 2, 3, 4, 5];
    reverse(&mut v);
    println!("{:?}", v);
}
```

*You should see:*

```text
[5, 4, 3, 2, 1]
```
<!-- /solution -->

**52.9 ★★★★ Words, as slices.** `fn words(s: &str) -> Vec<&str>` splitting on spaces by hand (walk the bytes with
`s.char_indices()`, slice between spaces), without `split`. Check it against
`s.split_whitespace().collect::<Vec<_>>()`.

<!-- solution 52.9 -->
```rust
fn words(s: &str) -> Vec<&str> {
    let mut out = Vec::new();
    let mut start = None;
    for (i, c) in s.char_indices() {
        match (c == ' ', start) {
            (false, None) => start = Some(i),
            (true, Some(st)) => {
                out.push(&s[st..i]);
                start = None;
            }
            _ => {}
        }
    }
    if let Some(st) = start {
        out.push(&s[st..]);
    }
    out
}

fn main() {
    let s = "  the borrow  checker is   kind ";
    let mine = words(s);
    println!("{:?} {}", mine, mine == s.split_whitespace().collect::<Vec<_>>());
}
```

*You should see:*

```text
["the", "borrow", "checker", "is", "kind"] true
```
<!-- /solution -->
