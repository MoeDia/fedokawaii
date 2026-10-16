#!/usr/bin/env python3
"""tests/menus/portal.py — xdg-desktop-portal-termfilechooser 1.4.3 (the version setup.sh
builds: src/filechooser/filechooser.c at cb8cec0) as it calls its wrapper, without D-Bus:

  portal.py open MULTIPLE DIRECTORY FOLDER     an OpenFile request
  portal.py save FOLDER NAME                   a SaveFile request (create_help_file=1)

It runs  "$CMD MULTIPLE DIRECTORY WRITING 'PATH' 'OUT' DEBUG"  through /bin/sh, as system()
does ("'" in PATH written as '\\''), then reads OUT as the portal does and prints what the
app would get: "uri FILE-URI" lines, or "cancelled" / "error: …". For a save it first makes
the stand-in file (adding "_" while the name is taken) and afterwards removes it unless it is
the answer, printing "made PATH" and "removed PATH". Settings from the environment:
PORTAL_CMD (the wrapper), PORTAL_OUT (default /tmp/termfilechooser-UID.portal), PORTAL_DEBUG.
"""
import os
import stat
import subprocess
import sys
from urllib.parse import quote, unquote_to_bytes

INSTRUCTIONS = (
    "* xdg-desktop-portal-termfilechooser instructions *\n"
    "---------------------------------------------------\n\n"
    "\t\t\t!!! WARNING !!!\n"
    "Opening a file OVERWRITES it!\n\n"
    "How to save *this* file:\n"
    "1) Move the file to your \n"
    "   desired location.\n"
    "2) Rename the file if needed.\n"
    "3) Open the file.\n\n"
    "Tips:\n"
    "- If you quit without opening\n"
    "  a file, the save operation\n"
    "  is cancelled."
    "\n\n---------------------------------------------------\n"
    "* xdg-desktop-portal-termfilechooser instructions *"
)


def escape_path(p: bytes) -> bytes:
    return p.replace(b"'", b"'\\''")


def run(writing, multiple, directory, path: bytes):
    """exec_filechooser: None on error, else the list of URIs (maybe empty)."""
    cmd = os.environ["PORTAL_CMD"].encode()
    out = os.environ.get("PORTAL_OUT", "/tmp/termfilechooser-%d.portal" % os.getuid()).encode()
    debug = os.environ.get("PORTAL_DEBUG", "0")
    line = b"%s %d %d %d '%s' '%s' %s" % (cmd, multiple, directory, writing,
                                           escape_path(path), out, debug.encode())
    if os.path.exists(out):
        open(out, "w").close()                          # cleared, if it is there
    r = subprocess.run([b"/bin/sh", b"-c", line])
    if r.returncode != 0:
        try:
            os.remove(out)
        except OSError:
            pass
        return None
    try:
        data = open(out, "rb").read()
    except OSError:
        return None
    # count the lines with characters, then read that many lines in order (as getline does)
    n = sum(1 for l in data.split(b"\n") if l)
    os.remove(out)
    if n == 0:
        return []
    lines = data.split(b"\n")
    uris = []
    for l in lines[:n]:
        uris.append("file://" + quote(l, safe="/"))
    return uris


def show(uris):
    if uris is None:
        print("error: the wrapper failed")
    elif not uris:
        print("cancelled")
    else:
        for u in uris:
            print("uri " + u)


def main():
    if sys.argv[1] == "open":
        multiple, directory, folder = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
        show(run(0, multiple, directory, os.fsencode(folder)))
        return
    folder, name = sys.argv[2], sys.argv[3]
    if not name:
        name = "termfilechooser.tmp"
    name = name.rsplit("/", 1)[-1] or "termfilechooser.tmp"
    path = os.fsencode(folder) + b"/" + os.fsencode(name)
    while os.path.exists(path):
        path += b"_"
    with open(path, "w") as f:
        f.write(INSTRUCTIONS)
    print("made " + os.fsdecode(path))
    uris = run(1, 0, 0, path)
    if uris is None or len(uris) != 1:
        if os.path.exists(path):
            os.remove(path)
            print("removed " + os.fsdecode(path))
        show(uris if uris is None or not uris else None)
        if uris and len(uris) > 1:
            print("error: too many selected SaveFiles")
        return
    chosen = unquote_to_bytes(uris[0][len("file://"):])
    try:
        st = os.stat(chosen)
    except OSError as e:
        print("error: failed to stat %s: %s" % (os.fsdecode(chosen), e.strerror))
        return
    if stat.S_ISDIR(st.st_mode):
        print("error: selected SaveFile is a directory")
        return
    if chosen != path and os.path.exists(path):
        os.remove(path)
        print("removed " + os.fsdecode(path))
    show(uris)


main()
