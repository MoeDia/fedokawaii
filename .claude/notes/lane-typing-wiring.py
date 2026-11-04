#!/usr/bin/env python3
"""lane-typing-wiring.py — the typing app wired into the files other lanes and the main run own: run it once from the root of
the merged tree, after chess's patch or before it, on whichever lanes are in:

    python3 -I .claude/notes/lane-typing-wiring.py          (it says what it did; run twice, the second time changes nothing)

Super+U (system/fedokawaii): typing leaves SOON, opens the app, its pane says where you are. Its tests (test_menu). Super+/ :
the app's icon, its sheet, test_help. docs/design-system.md: §2's display size, §7 the app, §14 its row. Anchors it cannot find
are named, and the exit status is 1: nothing is half done silently.
"""
import os
import re
import sys

done, missing = [], []


def edit(path, name, fn):
    with open(path) as f:
        s = f.read()
    t = fn(s)
    if t is None:
        missing.append(f'{path}: {name}')
    elif t != s:
        with open(path, 'w') as f:
            f.write(t)
        done.append(f'{path}: {name}')


def sub(pattern, repl, already=None, flags=0):
    """one re.sub as an edit: None when the pattern is not there and neither is the sign that it was done"""
    def fn(s):
        if already and already in s:
            return s
        t, n = re.subn(pattern, repl, s, flags=flags)
        return t if n else None
    return fn


SYS = 'system/fedokawaii'
edit(SYS, 'typing leaves SOON', lambda s: (lambda m: s if m and 'typing' not in m[1] else None if not m else
     s[:m.start(1)] + '|'.join(a for a in m[1].split('|') if a != 'typing') + s[m.end(1):])(re.search(r"^SOON='([^']*)'", s, re.M)))
edit(SYS, 'its row, on the desktop', sub(r'''^ *(?:command -v kawa-typing >/dev/null && )?e learning\s+typing\s+"\$\{ICON_KEYBOARD:-·\}"\s+typing\s+""[^\n]*$''',
     lambda m: '''  [[ -n $desk ]] && e learning typing "${ICON_KEYBOARD:-·}" typing ""   # (it draws in foot: not on a text console)''',
     '[[ -n $desk ]] && e learning typing', re.M))
edit(SYS, 'its pane', sub(r'''^    typing\)    soon "touch typing, finger by finger, to 100 words" \\\n\s+"a minute\." ;;\n''',
     '''    typing)    say "touch typing, finger by finger, to 100 words" \\\\
                   "a minute." ""
               while IFS= read -r l; do say "$l"; done < <(kawa-typing --status 2>/dev/null) ;;
''', 'kawa-typing --status', re.M))
edit(SYS, 'enter opens it, the warm window goes back', sub(r'''launch="([^)"]*)\) echo''', r'''launch="\1|typing) echo''', '|typing) echo', 0))
OPEN = "    typing)    setsid -f kawa-term --float --once typing --dialog typing 79x38 -- kawa-typing >/dev/null 2>&1 </dev/null; return 0 ;;\n"
edit(SYS, 'how it opens', sub(r'''^(    keys\)      setsid -f kawa-help [^\n]*\n)''', lambda m: m[1] + OPEN, 'kawa-term --float --once typing', re.M))

MENU = 'tests/engine/test_menu.sh'


def menu_soon(s):
    """the loop over what is not built yet: without typing; with nothing left in it, gone with its heading"""
    m = re.search(r'^case_ "rows: what is not built yet[^\n]*\nfor a in ([^;\n]*); do\n.*?^done\n', s, re.S | re.M)
    if not m:
        return s if 'what is not built yet' not in s else None
    left = [a for a in m[1].split() if a != 'typing']
    if left:
        return s[:m.start(1)] + ' '.join(left) + s[m.end(1):]
    return s[:m.start()] + s[m.end():]


edit(MENU, 'typing is no more "soon"', menu_soon)
edit(MENU, 'no typing on a text console', lambda s: re.sub(r'''(--rows learning [^\n]*"(?:guide|learn)(?: chess)?) typing "''', r'\1 "', s))
edit(MENU, 'the popup: enter opens it', lambda s: re.sub(
     r"""in held((?:\\\\\|chess)?)\\\\\|typing\\\\\) ;; ((?:guide|learn)\\\\\|keys\\\\\|change(?:\\\\\|chess)?)\\\\\) echo""",
     lambda m: f"in held{m[1]}\\\\) ;; {m[2]}\\\\|typing\\\\) echo", s))
edit(MENU, 'a text console: enter opens it', lambda s: re.sub(r"""in held((?:\\\|chess)?)\\\|typing\\\) ;; remind\\\)""", lambda m: f"in held{m[1]}\\) ;; remind\\)", s))

HELP = 'bin/kawa-help'
edit(HELP, 'its sheet has its icon', sub(r'''(system\) K=\$ICON_\w+ ;;)''', r'\1 typing) K=$ICON_KEYBOARD ;;', 'typing) K=$ICON_KEYBOARD'))
edit('tests/menus/test_help.sh', 'its sheet in the list', lambda s: s.replace(' visidata wallpaper', ' typing visidata wallpaper') if ' typing visidata wallpaper' not in s else s)

SHEET = 'configs/home/.config/fedokawaii/keys/typing.txt'
if not os.path.exists(SHEET):
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    with open(SHEET, 'w') as f:
        f.write("""# typing (Super+U, learning): touch typing, the keyboard and the hands in the terminal
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
    done.append(f'{SHEET}: written')

DOC = 'docs/design-system.md'
edit(DOC, '§14 its row', sub(r'''^(\| the prompt \| every terminal \|[^\n]*\n)''',
     lambda m: m[1] + '| typing | Super+U, learning | `bin/kawa-typing` (`configs/home/.local/lib/fedokawaii/kawatype`) | T26b |\n', '| typing | Super+U, learning |', re.M))
edit(DOC, '§2 its display size', sub(r'''The lock's(\s+)quote is not set in a font''',
     lambda m: f"The words typed in the typing app stand at ×2 beside its keyboard at ×2 and ×3, at ×1 beside it at ×1 (the letter on the screen is the letter on the key), its speed at ×3. The lock's{m[1]}quote is not set in a font",
     'The words typed in the typing app'))
APP = """- **The typing app** (`kawa-typing`, sixel tiles in foot, §4's parts in pixels). One stage on every screen: one column, the keyboard
  (his K617, 61 keys) and the hands (the demon's on the dark, the angel's on the light) at its foot, on the same pixels on home,
  in a lesson and on its result; what the screen is about stands over them, a row of words between; the window 79 × 38. One
  drawing, on a grid where a key is 20 × 20 — a row, the em on its rows 3–16, the capitals on 5–14 — shown whole at ×1, ×2 or ×3,
  whichever the window has room for; a window too small loses the hands, then the keyboard. A finger's colour is its nail's and
  the lit key's: Wada's four papers (§1: little `paper_mark`, ring `paper_folder`, middle `paper_git`, index `paper_time`, the
  same on both hands), a thumb `gold`; on them the ink of the prompt's papers. Typed words `faint`; a wrong one on the lacquer
  (`select`); the caret a vermilion block, its letter `text_on_accent`. A key held on the real keyboard goes down a pixel (× the
  multiple) and loses its lip; a wrong key `accent` until let go. A heading's rule burns in `accent_text` as the lesson goes. A
  clean run lifts embers from the demon's hands, petals from the angel's. Seals are stamped one after another 140 ms apart (§11's
  stamp), a flame in them on the dark, a lotus on the light.

"""
edit(DOC, '§7 the app', sub(r'''^(## 8\. The bar\n)''', lambda m: APP + m[1], '**The typing app**', re.M))

for line in done:
    print('done     ', line)
for line in missing:
    print('NOT FOUND', line)
print(f'{len(done)} edits, {len(missing)} anchors not found')
sys.exit(1 if missing else 0)
