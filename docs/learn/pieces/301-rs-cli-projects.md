---
id: rs-cli-projects
title: projects
part: rust
chapter: 62
minutes: 30
needs: [rs-cli-practice]
optional: yes
---

**62.4 ★★★ Parallel.** `cargo add rayon` and count each file on its own core
(`files.par_iter()`), merging the maps at the end. Is it faster on many files?
