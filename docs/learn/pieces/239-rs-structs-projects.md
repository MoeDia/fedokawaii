---
id: rs-structs-projects
title: projects
part: rust
chapter: 53
minutes: 180
needs: [rs-structs-practice]
optional: yes
---

**53.7 ★★★ A stack of plates.** `struct Stack { items: Vec<String> }` with `push`, `pop -> Option<String>`, `peek -> Option<&String>`,
`len`, `is_empty` — each method with the right kind of `self`.

<!-- solution 53.7 -->
```rust
struct Stack {
    items: Vec<String>,
}

impl Stack {
    fn new() -> Self {
        Stack { items: Vec::new() }
    }
    fn push(&mut self, s: &str) {
        self.items.push(s.to_string());
    }
    fn pop(&mut self) -> Option<String> {
        self.items.pop()
    }
    fn peek(&self) -> Option<&String> {
        self.items.last()
    }
    fn len(&self) -> usize {
        self.items.len()
    }
    fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
}

fn main() {
    let mut s = Stack::new();
    s.push("a");
    s.push("b");
    println!("{:?}", s.peek());
    println!("{:?} {} {}", s.pop(), s.len(), s.is_empty());
}
```

*You should see:*

```text
Some("b")
Some("b") 1 false
```
<!-- /solution -->

**53.8 ★★★ Builder.** A `Request` with `url`, `method` (default `"GET"`) and `timeout` (default 30): build it with
methods that take and return `self` — `Request::new(url).method("POST").timeout(5)`.

<!-- solution 53.8 -->
```rust
#[derive(Debug)]
struct Request {
    url: String,
    method: String,
    timeout: u32,
}

impl Request {
    fn new(url: &str) -> Self {
        Request { url: url.into(), method: "GET".into(), timeout: 30 }
    }
    fn method(mut self, m: &str) -> Self {
        self.method = m.into();
        self
    }
    fn timeout(mut self, t: u32) -> Self {
        self.timeout = t;
        self
    }
}

fn main() {
    println!("{:?}", Request::new("https://example.com").method("POST").timeout(5));
}
```

*You should see:*

```text
Request { url: "https://example.com", method: "POST", timeout: 5 }
```
<!-- /solution -->

**53.9 ★★★★ A matrix.** `struct Matrix { rows: usize, cols: usize, data: Vec<f64> }` (row after row in one `Vec`) with
`new(rows, cols)` (zeros), `get(r, c)`, `set(r, c, v)`, `transpose()`, and `matmul(&self, other)`
that panics with a clear message when the sizes do not fit. Check a 2 × 3 times 3 × 2.

<!-- solution 53.9 -->
```rust
#[derive(Debug, Clone, PartialEq)]
struct Matrix {
    rows: usize,
    cols: usize,
    data: Vec<f64>,
}

impl Matrix {
    fn new(rows: usize, cols: usize) -> Self {
        Matrix { rows, cols, data: vec![0.0; rows * cols] }
    }
    fn from(rows: usize, cols: usize, data: &[f64]) -> Self {
        assert_eq!(data.len(), rows * cols);
        Matrix { rows, cols, data: data.to_vec() }
    }
    fn get(&self, r: usize, c: usize) -> f64 {
        self.data[r * self.cols + c]
    }
    fn set(&mut self, r: usize, c: usize, v: f64) {
        self.data[r * self.cols + c] = v;
    }
    fn transpose(&self) -> Matrix {
        let mut t = Matrix::new(self.cols, self.rows);
        for r in 0..self.rows {
            for c in 0..self.cols {
                t.set(c, r, self.get(r, c));
            }
        }
        t
    }
    fn matmul(&self, o: &Matrix) -> Matrix {
        assert!(self.cols == o.rows, "cannot multiply {}x{} by {}x{}", self.rows, self.cols, o.rows, o.cols);
        let mut out = Matrix::new(self.rows, o.cols);
        for i in 0..self.rows {
            for j in 0..o.cols {
                let mut s = 0.0;
                for k in 0..self.cols {
                    s += self.get(i, k) * o.get(k, j);
                }
                out.set(i, j, s);
            }
        }
        out
    }
}

fn main() {
    let a = Matrix::from(2, 3, &[1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
    let p = a.matmul(&a.transpose());
    println!("{:?}", p.data);
}
```

*You should see:*

```text
[14.0, 32.0, 32.0, 77.0]
```
<!-- /solution -->
