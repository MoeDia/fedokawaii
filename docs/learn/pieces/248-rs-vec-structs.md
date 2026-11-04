---
id: rs-vec-structs
title: Vec of structs, sorting
part: rust
chapter: 55
minutes: 4
needs: [rs-vec]
optional: no
---

## 55.2 Vec of structs, sorting

```rust
#[derive(Debug)]
struct Player {
    name: String,
    score: u32,
}

fn main() {
    let mut players = vec![
        Player { name: "Sara".into(), score: 88 },
        Player { name: "Omar".into(), score: 95 },
        Player { name: "Lina".into(), score: 79 },
    ];
    players.sort_by_key(|p| std::cmp::Reverse(p.score));
    for (rank, p) in players.iter().enumerate() {
        println!("{}. {:<5} {}", rank + 1, p.name, p.score);
    }
    players.retain(|p| p.score >= 80);
    println!("{} kept", players.len());
}
```

*You should see:*

```text
1. Omar  95
2. Sara  88
3. Lina  79
2 kept
```

Floats cannot use `sort` (a `NaN` has no order); use `sort_by` with `total_cmp`:

```rust
fn main() {
    let mut xs: Vec<f64> = vec![2.5, -1.0, 9.75, 0.0];
    xs.sort_by(|a, b| a.total_cmp(b));
    println!("{:?}", xs);
}
```

*You should see:*

```text
[-1.0, 0.0, 2.5, 9.75]
```
