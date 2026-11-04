#!/usr/bin/python3 -I
import fcntl, glob, os, time
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
sfeat(fd, bytes.fromhex('0588b8000000')); time.sleep(0.06); m = gfeat(fd, 6, 1032); time.sleep(0.06)
sfeat(fd, bytes.fromhex('0583b6000000')); time.sleep(0.06); e = gfeat(fd, 6, 1032)
print('EXEC len', len(e), 'effect', hex(e[21]), 'flag38', hex(e[38]), 'sb39', hex(e[39]), 'mark', e[14:16].hex())
print('MODE colour[29:32]', m[29:32].hex(), '[218:221]', m[218:221].hex())
sfeat(fd, bytes.fromhex('0584d4000000')); time.sleep(0.06); k = gfeat(fd, 6, 1032)
print('keymap same as backup:', k[5:] == open('/dev/shm/r27-lane-hardware/state/k617-KEYMAP.bin','rb').read()[5:])
