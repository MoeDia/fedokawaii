---
id: rs-static
title: 'static; when in doubt, own it
part: rust
chapter: 58
minutes: 2
needs: [rs-no-need]
optional: no
---

## 58.5 'static

`'static` is the lifetime of the whole program. Text literals are `&'static str`: they are built
into the program file and never freed:

```rust
fn greeting(hour: u32) -> &'static str {
    if hour < 12 { "good morning" } else { "good evening" }
}

fn main() {
    let s: &'static str = "lives forever";
    println!("{s} — {}", greeting(9));
}
```

*You should see:*

```text
lives forever — good morning
```

> **Careful.** When the compiler suggests adding `'static`, it is rarely what you want. It
> usually means you are returning a reference to something you made — return the owned value
> (`String`, not `&str`) instead.

## 58.6 when in doubt, own it

Lifetimes are a tool for speed — borrowing instead of copying. While you learn, owning is always
a correct choice: a struct with `String` fields instead of `&str` needs no lifetimes at all. Make
it work with owned values, then borrow where profiling shows the copies matter.

| Field type | Lifetimes | Cost |
|---|---|---|
| `name: String` | none | one copy of the text |
| `name: &'a str` | the struct needs `<'a>` | no copy, but the text must outlive the struct |
