#!/usr/bin/python3 -I
"""hidprobe: read-only backup of MSI / K617 / cooler state. argv: outdir"""
import fcntl, glob, os, sys, time
out = sys.argv[1]
def ioc(nr, ln): return (3 << 30) | (ln << 16) | (ord('H') << 8) | nr
def sfeat(fd, data):
    b = bytearray(data); return fcntl.ioctl(fd, ioc(0x06, len(b)), b, True)
def gfeat(fd, rid, ln):
    b = bytearray(ln); b[0] = rid; r = fcntl.ioctl(fd, ioc(0x07, ln), b, True); return bytes(b[:r])
def find(vid, pid, iface):
    for h in sorted(glob.glob('/sys/class/hidraw/hidraw*')):
        u = open(h + '/device/uevent').read()
        if f'{vid:08X}:{pid:08X}' in u and u.split('HID_PHYS=')[1].split('\n')[0].endswith(f'input{iface}'):
            return '/dev/' + os.path.basename(h)
msi = find(0xdb0, 0x76, 0)
print('msi', msi)
fd = os.open(msi, os.O_RDWR)
d = gfeat(fd, 0x52, 185); open(out + '/msi-52.bin', 'wb').write(d)
print('msi 0x52 len', len(d)); print(d.hex())
os.close(fd)
k = find(0x258a, 0x49, 1)
print('k617', k)
fd = os.open(k, os.O_RDWR)
for name, sel in [('MODE', '0588b8000000'), ('CANVAS', '0589bc000000'), ('ROUTING', '0589c0000000'), ('EXEC', '0583b6000000')]:
    sfeat(fd, bytes.fromhex(sel)); time.sleep(0.06)
    d = gfeat(fd, 6, 1032); open(f'{out}/k617-{name}.bin', 'wb').write(d)
    print(name, len(d), d[:32].hex(), '...')
    time.sleep(0.06)
os.close(fd)
