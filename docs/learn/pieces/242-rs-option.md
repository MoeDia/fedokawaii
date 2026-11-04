---
id: rs-option
title: Option: maybe a value
part: rust
chapter: 54
minutes: 7
needs: [rs-match]
optional: no
---

## 54.5 Option: maybe a value

Rust has no `null` or `None` that can sneak in anywhere. A value that may be missing has the type
`Option<T>`, an enum from the standard library:

```rust
enum Option<T> {
    Some(T),   // there is a value, of type T
    None,      // there is not
}
```

The compiler will not let you use an `Option<i32>` as an `i32`: you must say what happens when
it is `None`. The commonest bug of other languages is gone.

```rust
fn find_index(names: &[&str], wanted: &str) -> Option<usize> {
    for (i, n) in names.iter().enumerate() {
        if *n == wanted {
            return Some(i);
        }
    }
    None
}

fn main() {
    let names = ["Sara", "Omar", "Lina"];
    for wanted in ["Omar", "Zaid"] {
        match find_index(&names, wanted) {
            Some(i) => println!("{wanted} is at {i}"),
            None => println!("no {wanted}"),
        }
    }
}
```

*You should see:*

```text
Omar is at 1
no Zaid
```

```rust
fn main() {
    let maybe: Option<i32> = Some(5);
    let n: i32 = maybe + 1;
}
```

*The compiler says:*

```text
error[E0369]: cannot add `{integer}` to `Option<i32>`
 --> src/main.rs:3:24
  |
3 |     let n: i32 = maybe + 1;
  |                  ----- ^ - {integer}
  |                  |
  |                  Option<i32>
  |
note: `Option<i32>` does not implement `Add<{integer}>`
```

The standard library returns `Option` wherever something may be missing:

```rust
fn main() {
    let v = vec![3, 9, 4];
    let empty: Vec<i32> = vec![];
    println!("{:?} {:?} {:?}", v.first(), empty.first(), v.get(10));
    println!("{:?} {:?}", "hello".find('l'), v.iter().max());
}
```

*You should see:*

```text
Some(3) None None
Some(2) Some(9)
```
