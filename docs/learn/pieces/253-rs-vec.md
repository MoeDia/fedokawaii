---
id: rs-vec
title: Vec: a growing list
part: rust
chapter: 55
minutes: 6
needs: [rs-enums-practice]
optional: no
---

> **In this chapter**
>
> - `Vec<T>`: a list that grows
> - `String` in depth: bytes, characters, building text
> - `HashMap` and `HashSet`: look up by key, keep unique values
> - `BTreeMap` for sorted keys, `VecDeque` for queues

## 55.1 Vec: a growing list

`Vec<T>` is Rust's list: values of one type `T`, in order, on the heap, growing as needed.
`vec![…]` makes one with values already in it:

```rust
fn main() {
    let mut v: Vec<i32> = Vec::new();
    v.push(3);
    v.push(1);
    v.push(2);
    let w = vec![10, 20, 30];
    println!("{:?} {} {:?}", v, v.len(), w);
    println!("{} {:?} {:?}", w[0], w.get(1), w.get(99));
    v.sort();
    let last = v.pop();
    println!("{:?} {:?} {}", v, last, v.contains(&1));
}
```

*You should see:*

```text
[3, 1, 2] 3 [10, 20, 30]
10 Some(20) None
[1, 2] Some(3) true
```

| Method | Does |
|---|---|
| `push(x)` · `pop()` | add at the end · take from the end (`Option`) |
| `v[i]` · `v.get(i)` | the item (panics past the end) · `Option<&T>` (never panics) |
| `insert(i, x)` · `remove(i)` | put at / take from position `i` |
| `len()` · `is_empty()` | size |
| `sort()` · `sort_by_key(f)` · `reverse()` · `dedup()` | in place |
| `contains(&x)` · `iter().position(…)` | search |
| `extend(other)` · `retain(f)` · `truncate(n)` · `clear()` | bulk changes |

Looping — three ways, by what you need:

```rust
fn main() {
    let mut scores = vec![72, 95, 61];
    for s in &scores {
        print!("{s} ");
    }
    println!();
    for s in &mut scores {
        *s += 5;
    }
    println!("{:?}", scores);
    for s in scores {
        print!("{s} ");
    }
    println!("(scores is gone now)");
}
```

*You should see:*

```text
72 95 61 
[77, 100, 66]
77 100 66 (scores is gone now)
```

| Loop over | Each item is | The Vec afterwards |
|---|---|---|
| `&v` | `&T`: read | still yours |
| `&mut v` | `&mut T`: change with `*` | still yours, changed |
| `v` | `T`: owned | moved: gone |
