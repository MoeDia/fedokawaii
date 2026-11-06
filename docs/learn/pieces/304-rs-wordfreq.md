---
id: rs-wordfreq
title: wordfreq
part: rust
chapter: 62
minutes: 11
needs: [rs-threads-practice]
optional: no
---

> **In this chapter**
>
> - a word-frequency tool, first with the standard library alone, then with clap
> - errors that tell the user what went wrong
> - install it as a command of your own

```text
$ cargo new wordfreq && cd wordfreq
$ cargo add clap --features derive
```

```rust
// wordfreq — the most common words in the files named, most common first
use clap::Parser;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// the most common words in some files
#[derive(Parser)]
struct Args {
    /// the files to read
    #[arg(required = true)]
    files: Vec<PathBuf>,
    /// how many words to show
    #[arg(short = 'n', long, default_value_t = 10)]
    top: usize,
    /// ignore words shorter than this
    #[arg(long, default_value_t = 1)]
    min_len: usize,
}

fn count(text: &str, min_len: usize, counts: &mut HashMap<String, usize>) {
    for word in text.split(|c: char| !c.is_alphanumeric()) {
        if word.chars().count() >= min_len.max(1) {
            *counts.entry(word.to_lowercase()).or_insert(0) += 1;
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let mut counts = HashMap::new();
    for f in &args.files {
        let text = fs::read_to_string(f).map_err(|e| format!("{}: {e}", f.display()))?;
        count(&text, args.min_len, &mut counts);
    }
    let mut top: Vec<(String, usize)> = counts.into_iter().collect();
    top.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    for (word, n) in top.iter().take(args.top) {
        println!("{n:6}  {word}");
    }
    Ok(())
}

```

And its tests, at the end of the same file:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_ignore_case_and_punctuation() {
        let mut c = HashMap::new();
        count("Tea, tea and TEA!", 1, &mut c);
        assert_eq!(c["tea"], 3);
        assert_eq!(c["and"], 1);
    }

    #[test]
    fn short_words_can_be_skipped() {
        let mut c = HashMap::new();
        count("a cup of tea", 3, &mut c);
        assert_eq!(c.len(), 2);
    }
}
```

```text
$ cargo run -q -- --help
the most common words in some files

Usage: wordfreq [OPTIONS] <FILES>...

Arguments:
  <FILES>...  the files to read

Options:
  -n, --top <TOP>          how many words to show [default: 10]
      --min-len <MIN_LEN>  ignore words shorter than this [default: 1]
  -h, --help               Print help
$ cargo run -q --release -- -n 5 --min-len 5 ~/dojo/fedokawaii/docs/fedokawaii-guide.md
$ cargo run -q -- /nope
Error: "/nope: No such file or directory (os error 2)"
```

*(the `///` comments become the help text; the `--` separates cargo's own options from your
program's)*

Install it as a command of your own, in cargo's own `bin` folder (on your `PATH`):

```text
$ cargo install --path .
$ wordfreq -n 3 ~/notes/notes.md
```
