---
id: rs-counter
title: checkpoint: a word counter that never panics
part: rust
chapter: 56
minutes: 40
needs: [rs-map-err]
optional: no
---

## 56.9 checkpoint project — a word counter that never panics

Level 3 in one program: read files, count words in a `HashMap`, sort them, and handle every
problem — a missing file, an empty file — with `Result` and `?`, never `unwrap` on outside data:

```rust
use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;

#[derive(Debug)]
enum CountError {
    Empty(String),
}

impl fmt::Display for CountError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            CountError::Empty(p) => write!(f, "{p} has no words"),
        }
    }
}

impl Error for CountError {}

fn top_words(path: &str, n: usize) -> Result<Vec<(String, usize)>, Box<dyn Error>> {
    let text = fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    let mut counts: HashMap<String, usize> = HashMap::new();
    for word in text.split(|c: char| !c.is_alphanumeric() && c != '\'') {
        if !word.is_empty() {
            *counts.entry(word.to_lowercase()).or_insert(0) += 1;
        }
    }
    if counts.is_empty() {
        return Err(Box::new(CountError::Empty(path.to_string())));
    }
    let mut pairs: Vec<(String, usize)> = counts.into_iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    pairs.truncate(n);
    Ok(pairs)
}

fn main() {
    fs::write("poem.txt", "The cat sat. The cat ate.\nThe dog did not.").unwrap();
    fs::write("empty.txt", "  \n").unwrap();
    for path in ["poem.txt", "empty.txt", "missing.txt"] {
        match top_words(path, 3) {
            Ok(words) => {
                println!("{path}:");
                for (w, c) in words {
                    println!("  {c:>3} {w}");
                }
            }
            Err(e) => println!("{path}: error: {e}"),
        }
    }
}
```

*You should see:*

```text
poem.txt:
    3 the
    2 cat
    1 ate
empty.txt: error: empty.txt has no words
missing.txt: error: missing.txt: No such file or directory (os error 2)
```

> **Checkpoint.** Take the file names from the command line (`std::env::args().skip(1)`), add a
> `--top N` option by hand, exit with code 1 if any file failed (`std::process::exit(1)`), and
> give `CountError` a second variant for a file over 100 MB (check `fs::metadata(path)?.len()`
> first). Level 3 done.
