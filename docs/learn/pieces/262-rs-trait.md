---
id: rs-trait
title: a trait
part: rust
chapter: 57
minutes: 8
needs: [rs-errors-practice]
optional: no
---

> **In this chapter**
>
> - traits: a behaviour many types can promise
> - implementing standard traits: `Display`, `Default`, `From`, `Add`, `Ord`
> - generics: one function or struct for many types, with trait bounds
> - `impl Trait` and `dyn Trait`: choosing at compile time or at run time

## 57.1 a trait

A **trait** names a behaviour — a set of methods — that different types can promise to have.
Each type **implements** it in its own way:

```rust
trait Speak {
    fn speak(&self) -> String;
}

struct Cat;
struct Dog {
    name: String,
}

impl Speak for Cat {
    fn speak(&self) -> String {
        "meow".to_string()
    }
}

impl Speak for Dog {
    fn speak(&self) -> String {
        format!("{} says woof", self.name)
    }
}

fn main() {
    println!("{}", Cat.speak());
    println!("{}", Dog { name: "Rex".into() }.speak());
}
```

*You should see:*

```text
meow
Rex says woof
```

A trait may give a **default** method, which every implementer gets for free (and may replace):

```rust
trait Describe {
    fn name(&self) -> String;
    fn describe(&self) -> String {
        format!("this is {}", self.name())
    }
}

struct Book(&'static str);
struct Song(&'static str);

impl Describe for Book {
    fn name(&self) -> String {
        format!("the book {}", self.0)
    }
}

impl Describe for Song {
    fn name(&self) -> String {
        self.0.to_string()
    }
    fn describe(&self) -> String {
        format!("♪ {} ♪", self.0)
    }
}

fn main() {
    println!("{}", Book("Dune").describe());
    println!("{}", Song("Sakura").describe());
}
```

*You should see:*

```text
this is the book Dune
♪ Sakura ♪
```
