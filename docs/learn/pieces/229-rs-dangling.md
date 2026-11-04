---
id: rs-dangling
title: no dangling references
part: rust
chapter: 52
minutes: 5
needs: [rs-last-use]
optional: no
---

## 52.5 no dangling references

A reference can never outlive the value it points at. Returning a reference to a local variable —
which is dropped as the function ends — is refused:

```rust
fn make() -> &String {
    let s = String::from("hi");
    &s
}

fn main() {
    let r = make();
}
```

*The compiler says:*

```text
error[E0106]: missing lifetime specifier
 --> src/main.rs:1:14
  |
1 | fn make() -> &String {
  |              ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value, but there is no value for it to be borrowed from
help: consider using the `'static` lifetime, but this is uncommon unless you're returning a borrowed value from a `const` or a `static`
  |
1 | fn make() -> &'static String {
  |               +++++++
help: instead, you are more likely to want to return an owned value
  |
1 - fn make() -> &String {
1 + fn make() -> String {
  |
```

The fix is to return the `String` itself — moving ownership out:

```rust
fn make() -> String {
    String::from("hi")
}

fn main() {
    let s = make();
    println!("{s}");
}
```

*You should see:*

```text
hi
```
