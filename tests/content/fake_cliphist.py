#!/usr/bin/env python3
"""fake_cliphist.py list|decode|delete|wipe|store — cliphist 0.7's answers from a folder
($CLIP_DB): each entry a file named by its id (the newest has the highest), its bytes the
copy. What `list` shows for an entry is what cliphist 0.7.0 shows (checked against it):
a picture Go can read (PNG, JPEG, GIF, BMP) as "[[ binary data SIZE FORMAT WxH ]]", anything
else as text — whitespace runs as one space, cut at 100 characters with "…", bytes that
are not UTF-8 as U+FFFD, other control characters (NUL, ESC) left as they are."""
import os, re, struct, sys

db = os.environ["CLIP_DB"]


def ids():
    return sorted((int(n) for n in os.listdir(db) if n.isdigit()), reverse=True)


def size(n):
    for u in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or u == "GiB": return "%.0f %s" % (n, u)
        n /= 1024


def picture(b):
    if b.startswith(b"\x89PNG\r\n\x1a\n"): return "png", struct.unpack(">II", b[16:24])
    if b[:6] in (b"GIF87a", b"GIF89a"): return "gif", struct.unpack("<HH", b[6:10])
    if b.startswith(b"BM") and len(b) > 26: return "bmp", struct.unpack("<ii", b[18:26])
    if b.startswith(b"\xff\xd8"):
        i = 2
        while i + 9 < len(b):
            if b[i] != 0xFF: break
            m, ln = b[i + 1], struct.unpack(">H", b[i + 2:i + 4])[0]
            if m in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", b[i + 5:i + 9]); return "jpeg", (w, h)
            i += 2 + ln
    return None


def preview(b):
    p = picture(b)
    if p: return "[[ binary data %s %s %dx%d ]]" % (size(len(b)), p[0], p[1][0], p[1][1])
    t = " ".join(re.split(r"[ \t\n\r\v\f]+", b.decode("utf-8", "replace").strip(" \t\n\r\v\f")))
    return t[:100] + "…" if len(t) > 100 else t


def bad(id_):
    sys.stderr.write('extracting id: converting id: strconv.Atoi: parsing "%s": invalid syntax\n' % id_); sys.exit(1)


def wanted():                      # delete: a line per entry, "ID<tab>…" or just "ID"
    out = []
    for line in sys.stdin.buffer.read().decode("utf-8", "replace").splitlines():
        id_ = line.split("\t", 1)[0]
        if not id_.isdigit(): bad(id_)
        out.append(int(id_))
    return out


def one():                         # decode: all of stdin is one entry — the ID is what comes
    s = sys.stdin.buffer.read().decode("utf-8", "replace")      # before a tab, or all of it
    id_ = s.split("\t", 1)[0]     # (so "ID\n" is no ID, as for cliphist itself)
    if not id_.isdigit(): bad(id_)
    return [int(id_)]


cmd = sys.argv[1] if len(sys.argv) > 1 else ""
if cmd == "list":
    for i in ids():
        sys.stdout.buffer.write(b"%d\t%s\n" % (i, preview(open(os.path.join(db, str(i)), "rb").read()).encode("utf-8", "surrogateescape")))
elif cmd == "decode":
    for i in one():
        f = os.path.join(db, str(i))
        if not os.path.exists(f):
            sys.stderr.write("id %d not found\n" % i); sys.exit(1)
        sys.stdout.buffer.write(open(f, "rb").read())
elif cmd == "delete":
    for i in wanted():
        try: os.remove(os.path.join(db, str(i)))
        except FileNotFoundError: pass
elif cmd == "wipe":
    for i in ids(): os.remove(os.path.join(db, str(i)))
elif cmd == "store":
    b = sys.stdin.buffer.read()
    if b.strip():
        n = (ids() or [0])[0] + 1
        open(os.path.join(db, str(n)), "wb").write(b)
else:
    sys.stderr.write("fake cliphist: %s?\n" % cmd); sys.exit(2)
