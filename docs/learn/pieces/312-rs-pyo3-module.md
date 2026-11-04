---
id: rs-pyo3-module
title: a Python module written in Rust
part: rust
chapter: 65
minutes: 8
needs: [loop-commit, rs-cli-practice]
optional: no
---

> **In this chapter**
>
> - write a Python module in Rust
> - build it into your uv project, call it from Python, measure the gain

The best of both: write the program in Python, find the slow part, rewrite only that in Rust,
and call it as if it were Python. This is how `tokenizers`, `pydantic-core`, `polars` and `ruff`
are made. **PyO3** is the bridge; **maturin** builds it.

```text
$ cd ~/repos
$ uvx maturin new --bindings pyo3 fastwords && cd fastwords
  Done! New project created fastwords
```

*(`uvx` runs a Python tool without installing it. maturin lays out a Rust crate that builds into a
Python module: `Cargo.toml`, `src/lib.rs`, `pyproject.toml`)*

Replace `src/lib.rs`:

```rust
use pyo3::prelude::*;

/// fastwords — word counting in Rust, called from Python
#[pymodule]
mod fastwords {
    use pyo3::prelude::*;
    use std::collections::HashMap;

    /// how many times each word appears (lower case, letters and digits only)
    #[pyfunction]
    fn count(text: &str) -> HashMap<String, usize> {
        let mut counts = HashMap::new();
        for w in text.split(|c: char| !c.is_alphanumeric()).filter(|w| !w.is_empty()) {
            *counts.entry(w.to_lowercase()).or_insert(0) += 1;
        }
        counts
    }

    /// the dot product of two lists of numbers
    #[pyfunction]
    fn dot(a: Vec<f64>, b: Vec<f64>) -> PyResult<f64> {
        if a.len() != b.len() {
            return Err(pyo3::exceptions::PyValueError::new_err("the lists differ in length"));
        }
        Ok(a.iter().zip(&b).map(|(x, y)| x * y).sum())
    }
}
```

Build it into the project's `.venv` and try it:

```text
$ uv run --with maturin maturin develop --release --uv
Installed fastwords-0.1.0
$ uv run python
>>> import fastwords
>>> fastwords.dot([1, 2, 3], [4, 5, 6])
32.0
>>> fastwords.dot([1], [1, 2])
ValueError: the lists differ in length
```

*(after each change to `lib.rs`, run the `maturin develop` line again. A Rust `HashMap` arrives in Python as a `dict`, a `Vec<f64>` is made from a list, and a Rust
error becomes a Python exception)*

And the race, in `bench.py`:

```python
import collections
import re
import time

import fastwords

text = "Tea, rice and green tea. " * 400_000
t = time.perf_counter(); rust = fastwords.count(text); t_rust = time.perf_counter() - t
t = time.perf_counter()
python = collections.Counter(w.lower() for w in re.findall(r"\w+", text))
t_python = time.perf_counter() - t
assert rust["tea"] == python["tea"] == 800_000
print(f"rust {t_rust:.2f} s · python {t_python:.2f} s")
```

```text
$ uv run bench.py
rust 0.57 s · python 2.82 s
```

*(for example: about five times faster here, on this desktop's processor)*
