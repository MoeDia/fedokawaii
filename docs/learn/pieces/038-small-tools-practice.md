---
id: small-tools-practice
title: practice
part: programs
chapter: 20
minutes: 16
needs: [sketch]
optional: no
---

**20.1 ★ A to-do.** In your notes, write `- [ ] finish chapter 20`. Later, make it `- [x]`.

**20.2 ★★ A table.** Save a few expenses as `~/practice/money.csv` (`date,item,amount`), open it
in VisiData, sort by amount, and find the total (on the amount column: **z+** then *sum*).

**20.3 ★★ JSON.** `curl -s "https://api.github.com/repos/neovim/neovim" | jq .stargazers_count`

*Expected:* one number: neovim's stars on GitHub.

**20.4 ★★ A booklet.** Take pages 1–3 of this guide (`docs/Fedokawaii-Learn.pdf` in your working
copy) and pages 1–2 of another PDF, merge them into one file, rotate its second page, lock it
with a password, and shrink it.

*Expected:* zathura asks for the password; `ls -l` shows the shrunk file smaller.
