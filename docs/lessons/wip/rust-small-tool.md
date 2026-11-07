---
id: rust-small-tool
title: A small tool in Rust
part: 2
minutes: 25
needs: [rust-errors]
---
## idea
Day 23's word counter again, in Rust, with what you now know. Read the file with std::fs::read_to_string(path), which returns a Result: a missing file is an Err you handle, not a crash. Walk the words with text.split_whitespace(). Keep the counts in a Vec of pairs (String, usize) so they stay in the order first seen; search it with iter_mut().find(...). Borrow where you only look, own where you keep.

## exercise
In ~/dojo/rs make words.txt holding: red blue red green blue red. Write count.rs: a function count(path: &str) -> Vec<(String, usize)> that returns an empty Vec when read_to_string fails, else the counts. In main print each pair like red 3, then print the length of count("none.txt").

## check
```check
run: rustc count.rs && ./count
in: rs
expect: red 3
expect: blue 2
expect: green 1
expect: 0
```

## answer
The match on read_to_string is the Rust twin of Python's try; the Err arm returns early with nothing.

```do
printf 'red blue red green blue red\n' > words.txt
```

```file count.rs
fn count(path: &str) -> Vec<(String, usize)> {
    let text = match std::fs::read_to_string(path) {
        Ok(t) => t,
        Err(_) => return Vec::new(),
    };
    let mut counts: Vec<(String, usize)> = Vec::new();
    for word in text.split_whitespace() {
        match counts.iter_mut().find(|p| p.0 == word) {
            Some(p) => p.1 += 1,
            None => counts.push((word.to_string(), 1)),
        }
    }
    counts
}

fn main() {
    for (w, n) in count("words.txt") {
        println!("{} {}", w, n);
    }
    println!("{}", count("none.txt").len());
}
```
