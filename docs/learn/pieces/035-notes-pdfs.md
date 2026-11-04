---
id: notes-pdfs
title: notes, books, PDFs
part: programs
chapter: 20
minutes: 2
needs: [desks-session]
optional: no
---

<!-- fig:notes | The notes window (Super+N): one file, a heading per day, ready to type. -->

| Tool | Opens with | Best at |
|---|---|---|
| notes | **Super+N** | one Markdown file, a heading per day: type at once, saved as you type |
| books | **Super+R** | your PDFs, EPUBs and comics, and this book; **Ctrl+A** brings books in from Downloads |
| zathura | opening a PDF | reading; **Ctrl+R** recolours the page to the theme |
| VisiData | `vd file.csv` | tables: sort (`[` `]`), select rows by a pattern (`|`), sum, group (**Shift+F**) |
| jq | `jq . file.json` | reading and reshaping JSON |
| gdu | `gdu ~` | what fills the disk |
| LibreOffice | opening a .docx, .xlsx, .pptx | office files |

## 20.1 PDFs: one tool for each job

| Job | Tool | Command |
|---|---|---|
| merge | qpdf | `qpdf --empty --pages a.pdf b.pdf -- merged.pdf` |
| some pages only | qpdf | `qpdf in.pdf --pages . 3-5 -- part.pdf` |
| split into pages | qpdf | `qpdf --split-pages in.pdf page-%d.pdf` |
| rotate | qpdf | `qpdf in.pdf --rotate=+90:2 out.pdf` (page 2; leave out `:2` for all) |
| lock with a password | qpdf | `qpdf --encrypt --user-password=OPEN --owner-password=OWNER --bits=256 -- in.pdf locked.pdf` |
| the text out | pdftotext (poppler) | `pdftotext -layout in.pdf out.txt` |
| the pictures out | pdfimages (poppler) | `pdfimages -png in.pdf img` → `img-000.png`, `img-001.png` … |
| smaller | ghostscript | `gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -sOutputFile=small.pdf in.pdf` |

*(`/ebook` is 150 dpi pictures; `/screen` smaller, `/printer` sharper. Super+Z runs the same
ghostscript on a PDF you copied, and Super+D (§6.5) runs the qpdf and poppler commands above)*
