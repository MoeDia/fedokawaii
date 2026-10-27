#!/usr/bin/env python3
"""tools/uinput-key.py — a key pressed on a keyboard the kernel believes in (uinput): for the
live checks no virtual Wayland keyboard can make — dwl keeps a virtual keyboard's locks and
layout apart from the real keyboards' group (Caps Lock on the bar, r27-17b), and the lock and
the saver wake on the real devices' input (T19, T20). No package: the uinput ioctls by hand.
Run as root (/dev/uinput): sudo python3 -I tools/uinput-key.py KEY… [--gap S]
  KEY  an evdev key name without KEY_ (CAPSLOCK, ESC, A, LEFTSHIFT…), pressed and let go in
       turn; NAME+NAME presses them together (LEFTALT+LEFTSHIFT)
  --gap S  seconds between keys (default 0.15)
The device is made, given 1 s for libinput and the compositor to take it in, used, then
destroyed. Exit 0 · 1 /dev/uinput unusable · 2 misuse."""
import fcntl, os, struct, sys, time

# linux/input-event-codes.h — the keys a check needs (add more as they are needed)
KEYS = {"ESC": 1, "A": 30, "S": 31, "Q": 16, "W": 17, "E": 18, "R": 19, "SPACE": 57,
        "CAPSLOCK": 58, "LEFTSHIFT": 42, "RIGHTSHIFT": 54, "LEFTCTRL": 29, "LEFTALT": 56,
        "LEFTMETA": 125, "ENTER": 28, "BACKSPACE": 14, "TAB": 15, "F12": 88}
EV_SYN, EV_KEY, SYN_REPORT = 0, 1, 0
UI_SET_EVBIT, UI_SET_KEYBIT = 0x40045564, 0x40045565          # _IOW('U', 100/101, int)
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502                # _IO('U', 1/2)
BUS_VIRTUAL = 0x06


def event(fd, typ, code, value):
    t = time.time()
    os.write(fd, struct.pack("llHHi", int(t), int((t % 1) * 1e6), typ, code, value))


def main(argv):
    gap, keys = 0.15, []
    it = iter(argv)
    for a in it:
        if a == "--gap":
            gap = float(next(it, "0.15"))
        elif a in ("-h", "--help"):
            print(__doc__); return 0
        else:
            names = a.upper().split("+")
            if not all(n in KEYS for n in names):
                print(f"uinput-key: no key {a!r} here (have: {' '.join(sorted(KEYS))})", file=sys.stderr); return 2
            keys.append([KEYS[n] for n in names])
    if not keys:
        print(__doc__, file=sys.stderr); return 2
    try:
        fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    except OSError as e:
        print(f"uinput-key: /dev/uinput: {e.strerror} (root needed)", file=sys.stderr); return 1
    try:
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
        for code in set(KEYS.values()):
            fcntl.ioctl(fd, UI_SET_KEYBIT, code)
        # struct uinput_user_dev: name[80], input_id (bustype, vendor, product, version),
        # ff_effects_max, absmax/absmin/absfuzz/absflat[64] each
        dev = struct.pack("80sHHHHi", b"fedokawaii-check-keyboard", BUS_VIRTUAL, 0x1209, 0x0001, 1, 0)
        os.write(fd, dev + b"\0" * (4 * 64 * 4))
        fcntl.ioctl(fd, UI_DEV_CREATE)
        time.sleep(1.0)
        for combo in keys:
            for c in combo:
                event(fd, EV_KEY, c, 1)
            event(fd, EV_SYN, SYN_REPORT, 0)
            time.sleep(0.03)
            for c in reversed(combo):
                event(fd, EV_KEY, c, 0)
            event(fd, EV_SYN, SYN_REPORT, 0)
            time.sleep(gap)
        time.sleep(0.2)
        fcntl.ioctl(fd, UI_DEV_DESTROY)
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
