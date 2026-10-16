#!/usr/bin/env python3
"""tests/yazi/mpvipc.py — talk to a running mpv over its JSON IPC socket.

    python3 mpvipc.py SOCKET get PROPERTY              its value, as JSON
    python3 mpvipc.py SOCKET until PROPERTY VALUE [S]  until it is VALUE (JSON), S seconds at most
    python3 mpvipc.py SOCKET near PROPERTY NUMBER [S]  until it is within 0.25 of NUMBER
    python3 mpvipc.py SOCKET run NAME [ARG…]           a command (numbers stay numbers)
    python3 mpvipc.py SOCKET wait [S]                  until the socket answers

Exit status: 0 done · 1 no answer, or not that value in time · 2 misuse.
"""
import json
import socket
import sys
import time


def ask(path, command, timeout=2.0):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(path)
    s.sendall((json.dumps({"command": command, "request_id": 7}) + "\n").encode())
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        buf += s.recv(65536)
        for ln in buf.split(b"\n"):
            if ln.strip():
                msg = json.loads(ln)
                if msg.get("request_id") == 7:
                    s.close()
                    return msg
    s.close()
    raise TimeoutError


def arg(a):
    try:
        return json.loads(a)
    except ValueError:
        return a


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    path, verb, rest = argv[0], argv[1], argv[2:]
    if verb == "wait":
        end = time.time() + float(rest[0] if rest else 5)
        while time.time() < end:
            try:
                ask(path, ["get_property", "pid"], 0.5)
                return 0
            except (OSError, TimeoutError, ValueError):
                time.sleep(0.05)
        return 1
    try:
        if verb == "get":
            r = ask(path, ["get_property", rest[0]])
            print(json.dumps(r.get("data")))
            return 0 if r.get("error") == "success" else 1
        if verb == "until":
            want, end = json.loads(rest[1]), time.time() + float(rest[2] if len(rest) > 2 else 5)
            while time.time() < end:
                r = ask(path, ["get_property", rest[0]])
                if r.get("data") == want:
                    return 0
                time.sleep(0.05)
            return 1
        if verb == "near":
            want, end = float(rest[1]), time.time() + float(rest[2] if len(rest) > 2 else 5)
            while time.time() < end:
                v = ask(path, ["get_property", rest[0]]).get("data")
                if isinstance(v, (int, float)) and abs(v - want) <= 0.25:
                    return 0
                time.sleep(0.05)
            return 1
        if verb == "run":
            r = ask(path, [rest[0], *map(arg, rest[1:])])
            return 0 if r.get("error") == "success" else 1
    except (OSError, TimeoutError, ValueError):
        return 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
