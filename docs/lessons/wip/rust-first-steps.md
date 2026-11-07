---
id: rust-first-steps
title: Rust, from the first print
part: 2
minutes: 15
needs: [reading-docs]
---
## idea
Rust is compiled: you write a file, the compiler rustc turns it into a program, and then you run that program. Two steps, where Python had one. Every program starts at a function called main. A line ends with a semicolon. println! prints a line; the exclamation mark says it is a macro, not a plain function. Text goes in double quotes, and {} inside it is a hole that takes a value after the comma.

```rust
fn main() {
    println!("hello {}", 3);
}
```

If the compiler finds a mistake it refuses and explains where. Read its message from the top: it is usually right.

## exercise
In ~/dojo/rs write hello.rs. Its main prints Hello from Rust, then prints 2 plus 3 is 5 by putting the sum 2 + 3 in the hole. Compile it with rustc hello.rs, then run ./hello.

## check
```check
run: rustc hello.rs && ./hello
in: rs
expect: Hello from Rust
expect: 2 plus 3 is 5
```

## answer
The compiler wrote a program called hello next to the source. Run it as many times as you like without compiling again.

```file hello.rs
fn main() {
    println!("Hello from Rust");
    println!("2 plus 3 is {}", 2 + 3);
}
```
