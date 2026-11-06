---
id: rs-scanner
title: checkpoint: a parallel file scanner
part: rust
chapter: 61
minutes: 40
needs: [rs-channels]
optional: no
---

## 61.8 checkpoint project — a parallel file scanner

Level 5 in one: modules of logic, iterators, closures, threads and a channel — searching every
`.txt` file in a folder for a word, one thread per file, results sent back and sorted:

```rust
use std::fs;
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread;

fn matching_lines(text: &str, word: &str) -> Vec<(usize, String)> {
    let w = word.to_lowercase();
    text.lines()
        .enumerate()
        .filter(|(_, l)| l.to_lowercase().contains(&w))
        .map(|(i, l)| (i + 1, l.trim().to_string()))
        .collect()
}

fn main() -> std::io::Result<()> {
    fs::create_dir_all("notes")?;
    fs::write("notes/a.txt", "buy rice\ncall Omar\n")?;
    fs::write("notes/b.txt", "Rice cooker broken\nfix bike\n")?;
    fs::write("notes/c.txt", "nothing here\n")?;

    let mut files: Vec<PathBuf> = fs::read_dir("notes")?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "txt"))
        .collect();
    files.sort();

    let (tx, rx) = mpsc::channel();
    for path in files {
        let tx = tx.clone();
        thread::spawn(move || {
            if let Ok(text) = fs::read_to_string(&path) {
                for (n, line) in matching_lines(&text, "rice") {
                    tx.send((path.display().to_string(), n, line)).unwrap();
                }
            }
        });
    }
    drop(tx);
    let mut hits: Vec<_> = rx.iter().collect();
    hits.sort();
    for (file, n, line) in &hits {
        println!("{file}:{n}: {line}");
    }
    println!("{} matches", hits.len());
    Ok(())
}
```

*You should see:*

```text
notes/a.txt:1: buy rice
notes/b.txt:1: Rice cooker broken
2 matches
```

> **Checkpoint.** Make it a cargo project with `matching_lines` in `src/lib.rs` (with tests), take
> the folder and the word from `std::env::args`, walk sub-folders too (a function that recurses
> into `read_dir`), and limit it to as many threads as cores (a channel of jobs that N workers
> take from). Time it on a big folder against `rg` (chapter 10). Level 5 done.
