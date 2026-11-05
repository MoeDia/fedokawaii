#!/usr/bin/python3 -I
"""the cooler's display: read its feature report; send a list of raw digit triples, each for SECONDS. argv: read | SECONDS HEX6 [HEX6...]"""
import fcntl, glob, os, sys, time
def ioc(nr, ln): return (3 << 30) | (ln << 16) | (ord('H') << 8) | nr
def gfeat(fd, rid, ln):
    b = bytearray(ln); b[0] = rid; r = fcntl.ioctl(fd, ioc(0x07, ln), b, True); return bytes(b[:r])
for h in sorted(glob.glob('/sys/class/hidraw/hidraw*')):
    u = open(h + '/device/uevent').read()
    if '00001A2C:00004184' in u and u.split('HID_PHYS=')[1].split('\n')[0].endswith('input1'):
        p = '/dev/' + os.path.basename(h)
fd = os.open(p, os.O_RDWR)
if sys.argv[1] == 'read':
    print(p, gfeat(fd, 7, 64).hex())
    sys.exit()
secs = float(sys.argv[1])
for hx in sys.argv[2:]:
    r = bytearray(64); d = bytes.fromhex(hx); r[0] = 7; r[1:1 + len(d)] = d
    print(time.strftime('%T'), r[:8].hex(), flush=True)
    end = time.time() + secs
    while time.time() < end:
        os.write(fd, r); time.sleep(0.25)
