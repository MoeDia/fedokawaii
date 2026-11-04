# the wiring, applied to the files as main has them: run in a tree of those files
p='system/fedokawaii'
s=open(p).read()
n=0
def rep(s, a, b):
    global n
    assert a in s, a[:60]
    n+=1
    return s.replace(a, b)
s=rep(s,"SOON='chess|typing'","SOON='chess'")
s=rep(s,"""  e learning  typing    "${ICON_KEYBOARD:-·}"   typing                 ""
""","""  [[ -n $desk ]] && e learning typing "${ICON_KEYBOARD:-·}" typing ""   # (it draws in foot: not on a text console)
""")
s=rep(s,"""    typing)    soon "touch typing, finger by finger, to 100 words" \\
                    "a minute." ;;
""","""    typing)    say "touch typing, finger by finger, to 100 words" \\
                   "a minute." ""
               while IFS= read -r l; do say "$l"; done < <(kawa-typing --status 2>/dev/null) ;;
""")
s=rep(s,"""    launch="guide|keys|change) echo""","""    launch="guide|keys|change|typing) echo""")
s=rep(s,"""    keys)      setsid -f kawa-help >/dev/null 2>&1 </dev/null; return 0 ;;     # (the sheet, by the bar)
""","""    keys)      setsid -f kawa-help >/dev/null 2>&1 </dev/null; return 0 ;;     # (the sheet, by the bar)
    typing)    setsid -f kawa-term --float --once typing --dialog typing 100x33 -- kawa-typing >/dev/null 2>&1 </dev/null; return 0 ;;
""")
open(p,'w').write(s)
p='tests/engine/test_menu.sh'
s=open(p).read()
s=rep(s,'for a in chess typing; do\n','for a in chess; do\n')
s=rep(s,'''eq "$(env -u WAYLAND_DISPLAY fedokawaii --rows learning | cut -f1 | tr '\\n' ' ')" "guide chess typing " "(the to-do''','''eq "$(env -u WAYLAND_DISPLAY fedokawaii --rows learning | cut -f1 | tr '\\n' ' ')" "guide chess " "(the to-do''')
s=rep(s,"""enter:transform:case \\\\{1\\\\} in held\\\\|chess\\\\|typing\\\\) ;; guide\\\\|keys\\\\|change\\\\) echo""","""enter:transform:case \\\\{1\\\\} in held\\\\|chess\\\\) ;; guide\\\\|keys\\\\|change\\\\|typing\\\\) echo""")
s=rep(s,"""'enter:transform:case \\{1\\} in held\\|chess\\|typing\\) ;; remind\\)""","""'enter:transform:case \\{1\\} in held\\|chess\\) ;; remind\\)""")
open(p,'w').write(s)
p='bin/kawa-help'
s=open(p).read()
s=rep(s,"""    wallpaper) K=$ICON_PICTURE ;; books) K=$ICON_BOOK ;; system) K=$ICON_SEC_SYSTEM ;;
""","""    wallpaper) K=$ICON_PICTURE ;; books) K=$ICON_BOOK ;; system) K=$ICON_SEC_SYSTEM ;; typing) K=$ICON_KEYBOARD ;;
""")
open(p,'w').write(s)
p='tests/menus/test_help.sh'
s=open(p).read()
s=rep(s,'"${ALL}bluetui books btop clipboard gdu lazygit mpv notes to-do nvim system torrra visidata wallpaper wiremix yazi zathura "','"${ALL}bluetui books btop clipboard gdu lazygit mpv notes to-do nvim system torrra typing visidata wallpaper wiremix yazi zathura "')
s=rep(s,'"yazi ${ALL}bluetui books btop clipboard gdu lazygit mpv notes to-do nvim system torrra visidata wallpaper wiremix zathura "','"yazi ${ALL}bluetui books btop clipboard gdu lazygit mpv notes to-do nvim system torrra typing visidata wallpaper wiremix zathura "')
open(p,'w').write(s)
p='docs/design-system.md'
s=open(p).read()
s=rep(s,"""| the prompt | every terminal | `configs/home/.bashrc.d/` | T24 |
""","""| the prompt | every terminal | `configs/home/.bashrc.d/` | T24 |
| typing | Super+U, learning | `bin/kawa-typing` (`configs/home/.local/lib/fedokawaii/kawatype`) | T26b |
""")
s=rep(s,"""  ×2 (28 px) for the boot splash, the boot menu (GRUB) and the installer's screens. The lock's
  quote is not set in a font at all: it is lettered by hand, pixel by pixel (§9).
""","""  ×2 (28 px) for the boot splash, the boot menu (GRUB) and the installer's screens, and for the
  words being typed in the typing app (×2 beside its keyboard at ×2 and ×3, ×1 beside it at ×1:
  the letter on the screen is the letter on the key), its speed ×3. The lock's quote is not set in
  a font at all: it is lettered by hand, pixel by pixel (§9).
""")
s=rep(s,"""## 8. The bar
""","""- **The typing app** (`kawa-typing`, sixel tiles in foot, §4's parts in pixels): the keyboard (his K617, 61 keys) and the
  hands (the demon's on the dark, the angel's on the light) one drawing on a grid where a key is 20 × 20 — a row, the em on
  its rows 3–16, the capitals on 5–14 — shown whole at ×1, ×2 or ×3, whichever the window has room for. The words typed are
  one column with the keyboard, its left edge theirs. A finger's colour is its nail's and the lit key's: Wada's four papers
  (§1: little `paper_mark`, ring `paper_folder`, middle `paper_git`, index `paper_time`, the same on both hands), a thumb
  `gold`; on them the ink of the prompt's papers. Typed words `faint`; a wrong one on the lacquer (`select`); the caret a
  vermilion block, its letter `text_on_accent`. A key held on the real keyboard goes down a pixel (× the multiple) and loses
  its lip; a wrong key `accent` until let go. A heading's rule burns in `accent_text` as the lesson goes. Seals are stamped
  one after another 140 ms apart (§11's stamp), a flame in them on the dark, a lotus on the light.

## 8. The bar
""")
open(p,'w').write(s)
import os
os.makedirs('configs/home/.config/fedokawaii/keys', exist_ok=True)
open('configs/home/.config/fedokawaii/keys/typing.txt','w').write("""# typing (Super+U, learning): touch typing, the keyboard and the hands in the terminal
# source: configs/home/.local/lib/fedokawaii/kawatype/app.py (Home.key, LessonScreen.key, Result.key)
── typing: Super+U → learning ─────────────────────────────────────
Enter                   go on: the next thing, on every screen
Tab / ← / →             the tabs: course, practice, progress
↑ / ↓ (j / k)           the one before / after
Esc                     out of a lesson (it is kept); back; close
Backspace               take a letter back (from the sentences on)
Tab, in a lesson        answer the eye
Ctrl+K                  quiet the next key's light, or bring it back
r                       after a lesson: the same one again
""")
print(n, 'edits')
