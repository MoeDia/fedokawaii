---
id: rs-partial
title: a partial move; common mistakes
part: rust
chapter: 51
minutes: 2
needs: [rs-own-loops]
optional: no
---

## 51.8 a partial move

Moving one field out of a struct (chapter 53) or tuple moves only that part; the rest stays
usable:

```rust
fn main() {
    let pair = (String::from("left"), String::from("right"));
    let l = pair.0;
    println!("{l} {}", pair.1);
}
```

*You should see:*

```text
left right
```

## 51.9 common mistakes

**1. `borrow of moved value`** (E0382). You moved a value, then used the old name. Choose:
borrow instead (`&x`, next chapter) — usually right; or `.clone()` if you truly need two.

**2. Cloning everything to make the errors go away.** It works, but costs memory and hides the
design. Ask first: does this function need to *own* the value, or only look at it?

**3. Expecting `let b = a;` to copy a String.** It moves. Only Copy types are copied.
