#!/usr/bin/python3 -I
"""the K617's keymap and macro blocks, read only, for the record. argv: outdir"""
import fcntl, glob, os, sys, time
out = sys.argv[1]
def ioc(nr, ln): return (3 << 30) | (ln << 16) | (ord('H') << 8) | nr
def sfeat(fd, data):
    b = bytearray(data); return fcntl.ioctl(fd, ioc(0x06, len(b)), b, True)
def gfeat(fd, rid, ln):
    b = bytearray(ln); b[0] = rid; r = fcntl.ioctl(fd, ioc(0x07, ln), b, True); return bytes(b[:r])
for h in sorted(glob.glob('/sys/class/hidraw/hidraw*')):
    u = open(h + '/device/uevent').read()
    if '0000258A:00000049' in u and u.split('HID_PHYS=')[1].split('\n')[0].endswith('input1'):
        p = '/dev/' + os.path.basename(h)
fd = os.open(p, os.O_RDWR)
for name, sel in [('KEYMAP', '0584d4000000'), ('MACRO', '0585dc000000')]:
    sfeat(fd, bytes.fromhex(sel)); time.sleep(0.06)
    d = gfeat(fd, 6, 1032); open(f'{out}/k617-{name}.bin', 'wb').write(d)
    print(name, len(d), d[:16].hex()); time.sleep(0.06)
