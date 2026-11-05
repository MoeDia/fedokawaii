#!/usr/bin/env python3
"""tools/regress/toplevels.py LOG — every window of this Wayland session, as it comes and goes.

Listens on ext_foreign_toplevel_list_v1 (dwl has it) and writes one line per event to LOG:
  open  ID  APP_ID  TITLE     close  ID
so that a window that only flashed by is on the record too. Runs until the session ends or it is
killed; lives in a test session (tools/hl-dwl.sh, a VM), never needs anything of the desktop's.
"""
import os
import socket
import struct
import sys

log = open(sys.argv[1], "a", buffering=1)
s = socket.socket(socket.AF_UNIX)
s.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))


def send(obj, op, payload=b""):
    s.sendall(struct.pack("=IHH", obj, op, 8 + len(payload)) + payload)


def string(b):
    n = struct.unpack_from("=I", b)[0]
    return b[4 : 4 + n - 1].decode("utf-8", "replace") if n else ""


REGISTRY, LIST = 2, 3
send(1, 1, struct.pack("=I", REGISTRY))  # wl_display.get_registry
handles = {}  # the server's new id -> [app_id, title, shown]
buf = b""
while True:
    d = s.recv(65536)
    if not d:
        break
    buf += d
    while len(buf) >= 8:
        obj, op, size = struct.unpack_from("=IHH", buf)
        if len(buf) < size:
            break
        body, buf = buf[8:size], buf[size:]
        if obj == REGISTRY and op == 0:  # wl_registry.global
            name = struct.unpack_from("=I", body)[0]
            iface = string(body[4:])
            if iface == "ext_foreign_toplevel_list_v1":
                z = iface.encode() + b"\0"
                z += b"\0" * (-len(z) % 4)
                send(REGISTRY, 0, struct.pack("=II", name, len(iface) + 1) + z + struct.pack("=II", 1, LIST))
        elif obj == LIST and op == 0:  # the list: a new window
            handles[struct.unpack_from("=I", body)[0]] = ["", "", False]
        elif obj in handles:
            h = handles[obj]
            if op == 0:  # closed
                log.write(f"close\t{obj:x}\n")
                del handles[obj]
            elif op == 1 and not h[2]:  # done: first complete description
                h[2] = True
                log.write(f"open\t{obj:x}\t{h[0]}\t{h[1]}\n")
            elif op == 2:
                h[1] = string(body)
            elif op == 3:
                h[0] = string(body)
