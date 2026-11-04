---
id: rs-own-projects
title: projects
part: rust
chapter: 51
minutes: 180
needs: [rs-own-practice]
optional: yes
---

**51.7 ★★★ Move into a struct.** `struct User { name: String }`. Make a `String`, move it into a `User`, then print the user's
name — and show that the original variable can no longer be used (comment it out after
reading the error).

<!-- solution 51.7 -->
```rust
struct User {
    name: String,
}

fn main() {
    let name = String::from("Sara");
    let u = User { name };
    // println!("{name}");  // error[E0382]: borrow of moved value: `name`
    println!("{}", u.name);
}
```

*You should see:*

```text
Sara
```
<!-- /solution -->

**51.8 ★★★ Swap ownership.** With `std::mem::swap(&mut a, &mut b)`, swap two `String`s without cloning; then with
`std::mem::take(&mut s)` take a string out of a variable, leaving an empty one.

<!-- solution 51.8 -->
```rust
fn main() {
    let mut a = String::from("left");
    let mut b = String::from("right");
    std::mem::swap(&mut a, &mut b);
    let taken = std::mem::take(&mut a);
    println!("[{a}] [{b}] [{taken}]");
}
```

*You should see:*

```text
[] [left] [right]
```
<!-- /solution -->

**51.9 ★★★★ Ownership on paper.** For this program, write down at every line who owns each `String`, and where each is dropped;
then add `Noisy` prints to check:
`let a = make("a"); let b = make("b"); let c = pick(a, b); let d = make("d"); drop(c);` with
`fn pick(x, y) -> returns x` (so `y` is dropped inside `pick`).

<!-- solution 51.9 -->
```rust
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("drop {}", self.0);
    }
}

fn make(s: &'static str) -> Noisy {
    Noisy(s)
}

fn pick(x: Noisy, _y: Noisy) -> Noisy {
    x
}

fn main() {
    let a = make("a");
    let b = make("b");
    let c = pick(a, b);
    println!("picked {}", c.0);
    let _d = make("d");
    drop(c);
    println!("end of main");
}
```

*You should see:*

```text
drop b
picked a
drop a
end of main
drop d
```
<!-- /solution -->
