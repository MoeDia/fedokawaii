---
id: rs-crates
title: crates from crates.io; common mistakes
part: rust
chapter: 59
minutes: 2
needs: [rs-more-tests]
optional: no
---

## 59.6 crates from crates.io

**crates.io** holds over 200 000 libraries. `cargo add` puts one in `Cargo.toml`; the next build
downloads and compiles it:

```text
$ cargo add rand
    Updating crates.io index
      Adding rand v0.9.2 to dependencies
$ grep -A1 dependencies Cargo.toml
[dependencies]
rand = "0.9.2"
```

| Crate | For |
|---|---|
| `serde`, `serde_json` | reading and writing JSON (and TOML, YAML…) into your structs |
| `clap` | command-line arguments (chapter 62) |
| `anyhow`, `thiserror` | errors: quick, and for libraries |
| `rand` | random numbers |
| `rayon` | data parallelism in one line (chapter 61) |
| `tokio`, `reqwest` | async, and HTTP |
| `candle`, `burn` | machine learning (chapter 64) |

`Cargo.lock` records the exact versions, as `uv.lock` does for Python: commit it for programs.

## 59.7 common mistakes

**1. `function is private`** (E0603) — add `pub`, to the item *and* to every module on the path.

**2. A module file not found** — `mod geometry;` needs `src/geometry.rs` (or
`src/geometry/mod.rs`), and must be written in `main.rs` or `lib.rs` (or the parent module).

**3. Tests that cannot see private functions** — unit tests in `mod tests` inside the same file
can (`use super::*;`); integration tests in `tests/` cannot, by design.
