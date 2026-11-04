---
id: rs-project
title: a project
part: rust
chapter: 48
minutes: 4
needs: [loop-commit]
optional: no
---

Rust asks more of you up front: it wants to know who owns every value. In return, a program that
compiles almost never crashes, and runs as fast as C. This part teaches it the same way as
Part IV — a course in six levels of tiny programs, mistakes, exercises and checkpoints — and ends
with Rust doing AI work: your own autograd, a model run in Rust, and Rust code called from Python.

> **In this chapter**
>
> - make, build, run and test a Rust project with cargo
> - a loop that checks your code on every save
> - read the compiler's messages: Rust's best teacher

Rust comes with **cargo**, one tool for the whole job: it makes projects, fetches libraries
(*crates*), builds, runs, tests, checks style. Setup has already installed Rust for you —
the stable toolchain with rust-analyzer, clippy and rustfmt, through rustup, in
`~/.local/share/cargo` — and `fedokawaii update` keeps it current. Check it is there:

```text
$ cargo --version
cargo 1.98.0 (…)
$ rustc --version
rustc 1.98.0 (…)
```

*(for example; a new Rust comes every six weeks: `fedokawaii update` runs `rustup update` for
you, or run it yourself)*

## 48.1 a project

```text
$ cd ~/repos && cargo new hello-rs && cd hello-rs
$ lt
.
├── Cargo.toml
└── src
   └── main.rs
$ cargo run
   Compiling hello-rs v0.1.0 (/home/you/repos/hello-rs)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.4s
     Running `target/debug/hello-rs`
Hello, world!
```

| Command | Does |
|---|---|
| `cargo run` | build and run |
| `cargo run --release` | the same, optimised: often ten times faster — use it for anything heavy |
| `cargo test` | run every test |
| `cargo check` | only check the code compiles: the quickest feedback |
| `cargo clippy` | advice: simpler, more idiomatic ways to write what you wrote |
| `cargo fmt` | format the code (neovim does it on save) |
| `cargo add NAME` | add a crate from crates.io |
| `cargo doc --open` | the documentation of your project and every crate it uses, in Brave |
