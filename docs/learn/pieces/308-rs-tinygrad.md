---
id: rs-tinygrad
title: tinygrad
part: rust
chapter: 63
minutes: 20
needs: [py-network-practice, rs-traits-practice]
optional: no
---

> **In this chapter**
>
> - numbers that remember how they were made
> - backpropagation over that record, by hand
> - a neuron, a network, XOR learnt

PyTorch's `loss.backward()` (chapter 44) seems like magic. It is a small idea: each number keeps
a note of the operation that made it and of its inputs; walking those notes backwards, applying
the chain rule at each, gives every gradient. Build it — about 120 lines — and the magic is gone
for good.

```text
$ cargo new tinygrad && cd tinygrad
```

```rust
// tinygrad — numbers that remember how they were made, and their gradients
use std::cell::RefCell;
use std::collections::HashSet;
use std::ops::{Add, Mul};
use std::rc::Rc;

enum Op {
    Leaf,
    Add(Value, Value),
    Mul(Value, Value),
    Tanh(Value),
}

struct Node {
    data: f64,
    grad: f64,
    op: Op,
}

#[derive(Clone)]
pub struct Value(Rc<RefCell<Node>>);

```

Its methods: making values, `tanh`, and `backward`, which walks the record from the end:

```rust
impl Value {
    pub fn new(data: f64) -> Value {
        Value(Rc::new(RefCell::new(Node { data, grad: 0.0, op: Op::Leaf })))
    }
    fn from_op(data: f64, op: Op) -> Value {
        Value(Rc::new(RefCell::new(Node { data, grad: 0.0, op })))
    }
    pub fn data(&self) -> f64 { self.0.borrow().data }
    pub fn grad(&self) -> f64 { self.0.borrow().grad }

    pub fn tanh(&self) -> Value {
        Value::from_op(self.data().tanh(), Op::Tanh(self.clone()))
    }

    /// every node this value was made from, children before parents
    fn topo(&self, seen: &mut HashSet<*const RefCell<Node>>, out: &mut Vec<Value>) {
        if !seen.insert(Rc::as_ptr(&self.0)) { return; }
        match &self.0.borrow().op {
            Op::Leaf => {}
            Op::Add(a, b) | Op::Mul(a, b) => { a.topo(seen, out); b.topo(seen, out); }
            Op::Tanh(a) => a.topo(seen, out),
        }
        out.push(self.clone());
    }

    pub fn backward(&self) {
        let mut order = Vec::new();
        self.topo(&mut HashSet::new(), &mut order);
        for v in &order { v.0.borrow_mut().grad = 0.0; }
        self.0.borrow_mut().grad = 1.0;
        for v in order.iter().rev() {
            let n = v.0.borrow();
            match &n.op {
                Op::Leaf => {}
                Op::Add(a, b) => {
                    a.0.borrow_mut().grad += n.grad;
                    b.0.borrow_mut().grad += n.grad;
                }
                Op::Mul(a, b) => {
                    let (ad, bd) = (a.data(), b.data());
                    a.0.borrow_mut().grad += bd * n.grad;
                    b.0.borrow_mut().grad += ad * n.grad;
                }
                Op::Tanh(a) => a.0.borrow_mut().grad += (1.0 - n.data * n.data) * n.grad,
            }
        }
    }

    pub fn step(&self, lr: f64) {
        let mut n = self.0.borrow_mut();
        n.data -= lr * n.grad;
    }
}

```

Then the two operators, so that `&a + &b` and `&a * &b` build nodes:

```rust
impl Add for &Value {
    type Output = Value;
    fn add(self, o: &Value) -> Value { Value::from_op(self.data() + o.data(), Op::Add(self.clone(), o.clone())) }
}
impl Mul for &Value {
    type Output = Value;
    fn mul(self, o: &Value) -> Value { Value::from_op(self.data() * o.data(), Op::Mul(self.clone(), o.clone())) }
}

```

On top of `Value`, a neuron, and the training — the same four steps as chapter 43:

```rust
/// one neuron: tanh(w·x + b)
struct Neuron { w: Vec<Value>, b: Value }

impl Neuron {
    fn new(inputs: usize, seed: &mut u64) -> Neuron {
        let mut r = || { *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
                         ((*seed >> 33) as f64 / (1u64 << 31) as f64) * 2.0 - 1.0 };
        Neuron { w: (0..inputs).map(|_| Value::new(r())).collect(), b: Value::new(0.0) }
    }
    fn forward(&self, x: &[Value]) -> Value {
        let mut s = self.b.clone();
        for (w, xi) in self.w.iter().zip(x) { s = &s + &(w * xi); }
        s.tanh()
    }
    fn params(&self) -> Vec<Value> { let mut p = self.w.clone(); p.push(self.b.clone()); p }
}

fn main() {
    // the gradient of one small expression, checked by hand
    let a = Value::new(2.0);
    let b = Value::new(-3.0);
    let c = &(&a * &b) + &a;            // c = a*b + a
    c.backward();
    println!("c = {}  dc/da = {}  dc/db = {}", c.data(), a.grad(), b.grad());

    // XOR with 4 hidden neurons
    let mut seed = 42;
    let hidden: Vec<Neuron> = (0..4).map(|_| Neuron::new(2, &mut seed)).collect();
    let out = Neuron::new(4, &mut seed);
    let data = [([0.0, 0.0], -1.0), ([0.0, 1.0], 1.0), ([1.0, 0.0], 1.0), ([1.0, 1.0], -1.0)];
    let mut params: Vec<Value> = hidden.iter().flat_map(|n| n.params()).collect();
    params.extend(out.params());

    for epoch in 0..=500 {
        let mut loss = Value::new(0.0);
        for (x, target) in &data {
            let x: Vec<Value> = x.iter().map(|&v| Value::new(v)).collect();
            let h: Vec<Value> = hidden.iter().map(|n| n.forward(&x)).collect();
            let diff = &out.forward(&h) + &Value::new(-target);
            loss = &loss + &(&diff * &diff);
        }
        loss.backward();
        for p in &params { p.step(0.05); }
        if epoch % 100 == 0 { println!("epoch {epoch:3}  loss {:.4}", loss.data()); }
    }
}
```

```text
$ cargo run -q --release
c = -4  dc/da = -2  dc/db = 2
epoch   0  loss 4.1237
epoch 100  loss 0.1982
epoch 200  loss 0.0463
epoch 300  loss 0.0239
epoch 400  loss 0.0157
epoch 500  loss 0.0116
```

Check the first line by hand: `c = a·b + a`, so `dc/da = b + 1 = -2` and `dc/db = a = 2`. The
rest is XOR — the classic problem a network without a hidden layer cannot learn — learnt.

| Rust idea | Why here |
|---|---|
| `Rc` | a value used by several later values has several owners: `Rc` counts them |
| `RefCell` | gradients are added from many places during `backward`: `RefCell` allows change through a shared handle, checked while it runs |
| `enum Op` | each node is exactly one kind of operation, and `match` handles each |
| `impl Add for &Value` | `&a + &b` builds a node: Rust lets your types use `+` and `*` |
