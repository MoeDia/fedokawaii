---
id: rs-candle
title: candle and burn
part: rust
chapter: 64
minutes: 7
needs: [py-torch-practice, rs-cli-practice]
optional: no
---

> **In this chapter**
>
> - load the digits network PyTorch trained, and run it in Rust
> - burn: a Rust framework that runs and trains on your card through Vulkan

Training is usually Python's job; *running* a trained model — in a command-line tool, a server,
a desktop program — is where Rust shines: one small binary, no Python, fast start. The bridge
is the **safetensors** file chapter 44 saved: plain tensors with names, readable from any
language.

| Framework | From | Runs on, here |
|---|---|---|
| **candle** | Hugging Face | the processor (its graphics backends are NVIDIA's CUDA and Apple's Metal) |
| **burn** | Tracel | the RX 9060 XT, through Vulkan (Mesa's driver, installed) |

## 64.1 candle: the PyTorch model, in Rust

```text
$ cargo new digits-candle && cd digits-candle
$ cargo add candle-core candle-nn anyhow
$ cp ../dl/digits.safetensors ../dl/test.safetensors .
```

```rust
// digits-candle — the PyTorch model's weights, run by candle: no Python at all
use candle_core::{DType, Device, D};
use candle_nn::{linear, Module, VarBuilder};

fn main() -> anyhow::Result<()> {
    let dev = Device::Cpu;
    // the weights, by the names PyTorch gave them: fc1.weight, fc1.bias, fc2.weight, fc2.bias
    let vb = unsafe { VarBuilder::from_mmaped_safetensors(&["digits.safetensors"], DType::F32, &dev)? };
    let fc1 = linear(64, 64, vb.pp("fc1"))?;
    let fc2 = linear(64, 10, vb.pp("fc2"))?;

    let test = candle_core::safetensors::load("test.safetensors", &dev)?;
    let (x, y) = (&test["x"], &test["y"]);

    let logits = fc2.forward(&fc1.forward(x)?.relu()?)?;
    let guess: Vec<u32> = logits.argmax(D::Minus1)?.to_vec1()?;
    let truth: Vec<i64> = y.to_vec1()?;
    let right = guess.iter().zip(&truth).filter(|(g, t)| **g as i64 == **t).count();
    println!("{right} of {} right ({:.1} %)", truth.len(), 100.0 * right as f64 / truth.len() as f64);
    println!("first ten: {:?}", &guess[..10]);
    Ok(())
}
```

```text
$ cargo run -q --release
273 of 297 right (91.9 %)
first ten: [1, 7, 4, 6, 3, 1, 3, 9, 1, 7]
```

*(for example: the same accuracy PyTorch printed at its last epoch — the same weights, the same
arithmetic, another language. `unsafe` here only says the file is mapped into memory: do not
change it while the program runs)*

## 64.2 burn: tensors on the card, through Vulkan

```text
$ cargo new burn-hello && cd burn-hello
$ cargo add burn --features vulkan
```

```rust
use burn::prelude::*;

fn main() {
    let device = Device::vulkan(Default::default());     // the card, through Vulkan
    let a = Tensor::<2>::from_data([[1.0, 2.0], [3.0, 4.0]], &device);
    let b = Tensor::<2>::ones([2, 2], &device);
    println!("{}", a.matmul(b));
}
```

```text
Tensor {
  data:
[[3.0, 3.0],
 [7.0, 7.0]],
  shape:  [2, 2],
…
```

*(`Tensor<2>` says how many dimensions it has: a shape mistake is a compile error, not a crash
after an hour of training. The device says where it lives — here the card)*
