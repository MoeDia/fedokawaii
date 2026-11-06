---
id: launcher-calc
title: launcher, calculator, downloads
part: desktop
chapter: 7
minutes: 11
needs: [desks-session]
optional: no
---

> **In this chapter**
>
> - start any program by a few letters of its name
> - calculate without opening a program
> - follow every download in one place

<!-- fig:launcher | The launcher (Super+Space). -->

## 7.1 the launcher

**Super+Space** (or the torii). Type a few letters — `hel` for Helium, `as` for ASOBI, `syn` for
Syncplay — and **Enter**. The programs you start most rise to the top. **Shift+Delete** makes one
forget its rank.

Each entry has its icon: a window program shows its own (Helium, LibreOffice); every other
entry — the terminal programs, the pages in Helium — one of the desktop's own **pixel icons**, in
the theme's red: a terminal for Terminal, a pair of brackets for the Editor, a folder for Files,
a branch for Git, a page for Notes, a clipboard, a calculator, a wrench for the file tools, a
picture for the wallpapers, a chip for the system monitor — after a week you find them by their
icon before you have read a word.

**Sums, without the calculator.** Type a sum in the launcher itself — `15% of 2400`,
`120 usd to aed` — and its answer appears as the first row while you type, with the calculator's
icon and *copy* at its right. **Enter** copies it: a notice says *copied*, the answer under it.

## 7.2 the calculator

*Calculator* in the launcher (**Super+Space**, `calc`), a small panel over whatever you are doing:
type a sum, a percentage or a conversion and the answer shows large as you type; **Enter** copies
it and keeps the sum below. **↑** brings back the sum before, **↓** goes down to the session's sums
(**Enter** copies one), **Ctrl+U** clears, **Ctrl+Q** opens qalc's own prompt, **Esc** closes.

| You type | You see |
|---|---|
| `15% of 2400` | `360` |
| `120 usd to aed` | the amount in dirhams (rates refreshed weekly) |
| `5 ft to cm` · `3.5 h to min` | `152.4 cm` · `210 min` |
| `sqrt(2)` · `255 to hex` | `1.414213562` · `0xFF` |

## 7.3 the downloads centre

Anything that downloads — the browser, a torrent, curl or yt-dlp in a terminal — shows in the bar's download mark as one
percent. Click it for the list: each download with its source, size and progress; a click opens
where it lands. A notice says when each one finishes.

### exercises

**7.1 ★ No mouse.** Start Helium, yazi and btop from the launcher alone.

**7.2 ★ Quick sums.** In the calculator: how many seconds in a week (`1 week to s`)?

*Expected:* `604800 s`.

**7.4 ★ A sum in the launcher.** **Super+Space**, type `15% of 2400`, **Enter**; paste into a
terminal.

*Expected:* the notice *15% of 2400 = 360 · copied*, and `360` pasted.

**7.3 ★★ Watch it arrive.** Download a Fedora image's checksum file in Helium
(`https://fedoraproject.org`) and watch the bar's mark, then click the finished notice.

*Expected:* the mark appears while it downloads and goes when it is done; the notice opens
`~/downloads`.
