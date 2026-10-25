# Owner's final-round requests (2026-10-21, verbatim intent) — the LAST round; everything must be fully fixed

Files from his machine: report /root/.claude/uploads/6d31fcd7-1ae3-5468-8ff5-715a71fb37a1/4331a062-fedokawaii-report__3_.txt (706 checks, 22 FAIL, 19 WARN — every one must be fixed or proven a false check), container trial /root/.claude/uploads/6d31fcd7-1ae3-5468-8ff5-715a71fb37a1/b21e7281-fedokawaii-trial.txt (setup --trial FAIL at s_repos line 862 rpmfusion release install; check-packages --live: %{repo_id} not expanded in repo query, missing-repo list before setup adds repos, stale gamemode evidence row, obsoletes noise).

1. `sudo bash fedokawaii.sh update` got stuck; had to run it again.
2. Black box (text console) still shows after choosing the kernel in the boot menu.
3. Calculator (kawa-calc) and notes: the footer hints ("enter copy", "↑ again"…) become artefacty/glitchy while typing — find the root cause.
4. Bar tooltips: minimal words, especially volume, brightness, RAM — essential point only.
5. Launcher icons: dislikes the duck icon (Files/yazi) and the sheep (Agents/herdr); create custom icons in our pixel style for terminal apps and apps without official icons (also the ones showing the neovim icon) — consistent, coherent set.
6. Clipboard (Super+V): the "newest first" input line is too close to the first entry.
7. Dark↔light switch: fast but not flawless at his click speed; he wants a transition better than the removed one, coherent with the wallpaper transition (maybe the same) — design in our DNA (no smooth easing; stepped/pixel).
8. Opening many terminals rapidly: text/lines still not re-laid properly. Restyle the prompt to the newest design system. Proper spacing between the cursor line and the prompt/first item in EVERY TUI where he types (prompt, Super+V clipboard, Super+W wallpaper, Super+U …); Syncplay TUI and Books (Super+R) are the good examples. Full alignment sweep; vertical line spacing is bad.
9. Super+N rapid toggle could be faster.
10. Screen recording entry in quick settings (and other suitable entries — decide).
11. Calendar dropdown: previous/next/today glitchy, delayed, sometimes unresponsive.
12. btop: better spaced, more consistent, more minimal.
13. Bar dropdowns: hovering options doesn't recolour until he clicks the menu first (focus/pointer) — all bar menus.
14. Volume mixer: the ◆ marker too close to the text ("HD-Audio Generic") — add proper space.
15. Torrents still not working; a python pip/pipx error notification keeps appearing.
16. Steam bar icon tooltip says "steam starting" although Steam is running.
17. Calculations / currency conversion typed in the app launcher don't work at all.
18. Opening/closing/resizing windows must be perfectly smooth: no split-second wrong-size frame before a new window shows; tune performance and monitor sync.
19. Learning guide far too short: needs many more simple examples, fundamentals explained, many more exercises and levels for Python and Rust, to real proficiency.
20. Wallpapers change automatically every 4 hours (toggle in the Super+W menu); add 50 more per theme (100 total), solid choices in the current selection's spirit; a beautiful retro-Japanese wallpaper transition.
21. Blasphemous doesn't work — diagnose properly; pick the most stable/performant Proton that works.
22. Yazi as file picker (save dialog): jumbled, overlapping (folder icon over "save file"), "..." truncation; yazi's alignment/spacing/theme overall disappointing — fix thoroughly.
23. Font slightly thicker for readability in UI and terminal — make an executive decision.
24. Waking from the screensaver: slow, a black screen first before the lock; the lock looks too thin.
25. PDF size reduction in the file menu (Super+Z-like for PDFs). Define clean behaviour: Super+Z on the highlighted image in the clipboard; in yazi Super+Z / Alt+F on one or several highlighted images or PDFs. Bug: Super+Z keeps using the last copied image even after the clipboard is cleared, and the size may always show 52 KB.
26. Alt+F menu and the screen-share window picker: first option not highlighted until arrow-down — decide the best behaviour (keyboard-first: highlight the first).
27. Screen sharing of a WINDOW didn't work at first until he spawned more windows and changed tiling — debug fully; must be rock solid; viewer-side quality could be better.
29. Sleep/wake with Enter: works.
33. Clean mic: no audible difference (quiet room) — verify it is really active.
34. Blasphemous after switching Proton: overlay showed 60 fps (cap?); switching workspace and back shows the game black — fix.
35. Downloads bar icon: show percentage, not bytes; progress for zipping/compression and PDF tools while running; solid, performant, all download sources included.
36. Recording: a pause/resume shortcut with an elegant 3-2-1 countdown on the bar; recording fullscreen games must perform well.
37. OCR: he has a 61-key keyboard with no Print key — bind screenshot/OCR keys reachable on it.
38. Fast clicking better but improve further system-wide.
40. Boot: on a fresh boot from shutdown the menu still appears with an orange progress bar; then the Fedora/starting image blinks black twice before the lock screen. Must be as smooth and coherent as Omarchy.
41. Every Super+U option works, connected to the PUBLIC repo (update pulls from GitHub MoeDia/fedokawaii); all custom menus optimized and aligned to the pixel.
42. Design: the colour change of the kanji next to the date and of the launcher icon (orange → white) is unsatisfying — something else in our DNA; the workspace square borders no longer fit — design something new, test it.
43. Treat every warning, failure, comment super seriously — he will use it for a long time with no more changes.
44. Token-efficient, sequential, careful, deterministic.
45. Screensaver must follow the current theme: light palette in light theme, dark in dark (like the lock screen) — verify saver.conf per theme is actually picked at run time.

## Report findings routed from step 1 (fix in the step named)
- step 2 (bar/session): mako double start (ENV-03, UNIT-03, SYS-01: autostart `mako &` races D-Bus activation — start only via systemctl --user after dwl-session.target); BAR-04, BAR-06, RES-03 (kawa-brightness --bar long-running not allowed-listed), PERF-05/07/09; UI-02 (kawa-panel), UI-16; THEME-22 (dwl XCURSOR_THEME=default, no default index.theme).
- step 3 (terminals): UI-11 (kawa-term --float); FONT-03 (Noto Kufi Arabic); two installed tools printing no version, named by hashes 7df01d…/56fc2d… in the report; herdr starts (verify ✘).
- step 5 (apps): torrra (uv python downloads manual → "No interpreter found for Python 3.13"; TOR-04/11/12); QALC-02/CALC-01 (qalc answers "rem(15, 1 B)"); GAME-05, GAME-15, SYS-02 (fossilize_replay/Proton crashes); SHARE-07; AUD-17; kawa-record vainfo needs --display drm.
- step 4 (theme/wallpaper): WALL-04, CLEAN-01.
