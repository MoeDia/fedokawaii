---
id: rs-own-practice
title: practice
part: rust
chapter: 51
minutes: 18
needs: [rs-partial]
optional: no
---

**51.1 ★ Which compile?.** For each, say whether it compiles, then check: (a) `let a = 5; let b = a; println!("{a}");`
(b) `let a = String::from("x"); let b = a; println!("{a}");` (c) the same with `a.clone()`.

<!-- solution 51.1 -->
```rust
fn main() {
    let a = 5;
    let _b = a;
    println!("(a) compiles: {a}");
    // (b) does not: a was moved into b (E0382)
    let s = String::from("x");
    let _t = s.clone();
    println!("(c) compiles: {s}");
}
```

*You should see:*

```text
(a) compiles: 5
(c) compiles: x
```
<!-- /solution -->

**51.2 ★ Fix with clone.** Make this compile by changing one line: `let s = String::from("hi"); let t = s; println!("{s} {t}");`

<!-- solution 51.2 -->
```rust
fn main() {
    let s = String::from("hi");
    let t = s.clone();
    println!("{s} {t}");
}
```

*You should see:*

```text
hi hi
```
<!-- /solution -->

**51.3 ★ Give it back.** `fn exclaim(s: String) -> String` adds `"!!"`; call it twice on the same text, keeping ownership.

<!-- solution 51.3 -->
```rust
fn exclaim(mut s: String) -> String {
    s.push_str("!!");
    s
}

fn main() {
    let s = exclaim(String::from("wow"));
    let s = exclaim(s);
    println!("{s}");
}
```

*You should see:*

```text
wow!!!!
```
<!-- /solution -->

**51.4 ★★ The drop order.** Make three `Noisy` values in `main`, one inside a block, and predict the order of the drop
lines before you run it.

<!-- solution 51.4 -->
```rust
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("drop {}", self.0);
    }
}

fn main() {
    let _x = Noisy("x");
    {
        let _y = Noisy("y");
    }
    let _z = Noisy("z");
    println!("end");
}
```

*You should see:*

```text
drop y
end
drop z
drop x
```
<!-- /solution -->

**51.5 ★★ Drop early.** `drop(value)` frees a value before the end of its scope. Show it with `Noisy`: the drop line comes
before `end`.

<!-- solution 51.5 -->
```rust
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("drop {}", self.0);
    }
}

fn main() {
    let a = Noisy("a");
    drop(a);
    println!("end");
}
```

*You should see:*

```text
drop a
end
```
<!-- /solution -->

**51.6 ★★ Count the clones.** Write `fn longest(a: String, b: String) -> String` returning the longer. Call it so that you can
still print both originals afterwards — how many `clone`s does that take? (Two. Chapter 52 gets
it down to none.)

<!-- solution 51.6 -->
```rust
fn longest(a: String, b: String) -> String {
    if a.len() >= b.len() { a } else { b }
}

fn main() {
    let x = String::from("tea");
    let y = String::from("coffee");
    let l = longest(x.clone(), y.clone());
    println!("{l} ({x}, {y})");
}
```

*You should see:*

```text
coffee (tea, coffee)
```
<!-- /solution -->
