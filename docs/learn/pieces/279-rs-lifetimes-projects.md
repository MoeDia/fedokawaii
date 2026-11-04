---
id: rs-lifetimes-projects
title: projects
part: rust
chapter: 58
minutes: 180
needs: [rs-lifetimes-practice]
optional: yes
---

**58.5 ★★★ A tokenizer that borrows.** `struct Tokens<'a> { rest: &'a str }` with a method `fn next_word(&mut self) -> Option<&'a str>`
returning words one at a time (skip spaces, slice up to the next space).

<!-- solution 58.5 -->
```rust
struct Tokens<'a> {
    rest: &'a str,
}

impl<'a> Tokens<'a> {
    fn next_word(&mut self) -> Option<&'a str> {
        let s = self.rest.trim_start();
        if s.is_empty() {
            return None;
        }
        let end = s.find(' ').unwrap_or(s.len());
        self.rest = &s[end..];
        Some(&s[..end])
    }
}

fn main() {
    let text = String::from("  rust  owns   memory ");
    let mut t = Tokens { rest: &text };
    while let Some(w) = t.next_word() {
        print!("[{w}]");
    }
    println!();
}
```

*You should see:*

```text
[rust][owns][memory]
```
<!-- /solution -->

**58.6 ★★★ Own instead.** Rewrite `Highlight<'a>` of 58.5 with `text: String`, so it needs no lifetime. What does each
version cost?

<!-- solution 58.6 -->
```rust
#[derive(Debug)]
struct Highlight {
    text: String,
    line: usize,
}

fn find(doc: &str, word: &str) -> Vec<Highlight> {
    doc.lines().enumerate().filter(|(_, l)| l.contains(word)).map(|(i, l)| Highlight { text: l.to_string(), line: i + 1 }).collect()
}

fn main() {
    let hits = {
        let doc = String::from("ownership\nborrowing rules");
        find(&doc, "borrow")
    };
    println!("{:?}", hits);
}
```

*You should see:*

```text
[Highlight { text: "borrowing rules", line: 2 }]
```
<!-- /solution -->

**58.7 ★★★★ Longest common prefix.** `fn common_prefix<'a>(words: &[&'a str]) -> &'a str` returning a slice of the first word — the
prefix all words share (careful with non-ASCII: compare `char_indices`).

<!-- solution 58.7 -->
```rust
fn common_prefix<'a>(words: &[&'a str]) -> &'a str {
    let Some(first) = words.first() else { return "" };
    let mut end = first.len();
    for w in &words[1..] {
        let mut e = 0;
        for ((i, a), b) in first.char_indices().zip(w.chars()) {
            if a != b {
                break;
            }
            e = i + a.len_utf8();
        }
        end = end.min(e);
    }
    &first[..end]
}

fn main() {
    println!("{:?} {:?}", common_prefix(&["fedora", "fedokawaii", "federal"]), common_prefix(&["京都", "京橋"]));
}
```

*You should see:*

```text
"fed" "京"
```
<!-- /solution -->
