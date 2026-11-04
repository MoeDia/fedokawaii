---
id: rs-neovim
title: in neovim; reading the compiler
part: rust
chapter: 48
minutes: 11
needs: [rs-project]
optional: no
---

## 48.2 in neovim

Rust support is set up already: **rust-analyzer** runs with the first `.rs` file. Types appear
beside each `let` in grey, errors are underlined as you type, `K` shows any function's
documentation and `gd` jumps into the standard library's own source. **Space c a** offers the
fixes the compiler suggests.

| Keys | Does |
|---|---|
| **Space r f** · **Space r c** | `cargo run` · `cargo check`, in a terminal under the code |
| **Space r t** · **Space r l** | `cargo test` · `cargo clippy` |
| **Space r r** | rust-analyzer's runnables: pick a test, a binary or an example to run |
| **Space t t** · **Space t r** · **Space t w** | this file's tests · the one under the cursor · on every save |
| **Space d b** · **Space d c** | a breakpoint · run with the debugger (codelldb), as in chapter 24 |

## 48.3 check on every save

Every save (**Ctrl+S**) runs clippy over the project: its findings appear in the code as you
work, no command needed. For the tests, **Space t w** in a file with tests: they run on every
save too, ✓ or ✗ in the margin.

## 48.4 reading the compiler

Rust's compiler explains itself. Make this mistake on purpose:

```rust
fn main() {
    let name = String::from("Kyoto");
    let other = name;
    println!("{name}");
}
```

```text
error[E0382]: borrow of moved value: `name`
 --> src/main.rs:4:16
  |
2 |     let name = String::from("Kyoto");
  |         ---- move occurs because `name` has type `String`, which does not implement the `Copy` trait
3 |     let other = name;
  |                 ---- value moved here
4 |     println!("{name}");
  |                ^^^^ value borrowed here after move
  |
help: consider cloning the value if the performance cost is acceptable
  |
3 |     let other = name.clone();
  |                     ++++++++
```

Read it as a story: line 2 made the value, line 3 *moved* it into `other`, line 4 tried to use
it after. And a fix. `rustc --explain E0382` tells the whole story with examples. Chapter 51
explains moving.

### exercises

**48.1 ★ Hello.** Make `hello-rs`, change the message, `cargo run`.

**48.2 ★ Break it.** Remove the `!` from `println!` and read the error; put it back.

*Expected:* the compiler says `println` is a macro and suggests the `!`.

**48.3 ★★ Release.** Write a loop summing the numbers 1 to 1 000 000 000 into a `u64`, and time
`cargo run` against `cargo run --release` (`time cargo run --release`).

*Expected:* the release build is many times faster.
