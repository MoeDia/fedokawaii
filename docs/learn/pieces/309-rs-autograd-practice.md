---
id: rs-autograd-practice
title: practice
part: rust
chapter: 63
minutes: 11
needs: [rs-tinygrad]
optional: no
---

**63.1 ★ Tests.** Turn the first line's check into a `#[test]`: `c.data() == -4.0`, `a.grad()
== -2.0`.

**63.2 ★★ More operations.** Add `Op::Pow(Value, f64)` (`d/dx xⁿ = n·xⁿ⁻¹`) and `exp`. Test each
gradient by nudging, as in 43.4.

**63.3 ★★ ReLU.** Add `relu` and train XOR with it instead of `tanh`. Faster or slower?
