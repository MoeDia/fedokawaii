#!/usr/bin/env python3
# run a command in a pty of COLS x ROWS and print its output: pty.py COLS ROWS CMD...
import os, pty, sys, struct, fcntl, termios, select, signal
cols, rows = int(sys.argv[1]), int(sys.argv[2])
pid, fd = pty.fork()
if pid == 0:
    os.environ.update(TERM="foot", COLORTERM="truecolor", COLUMNS=str(cols))
    os.execvp(sys.argv[3], sys.argv[3:])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
out=b""
while True:
    r,_,_=select.select([fd],[],[],5)
    if not r: break
    try: d=os.read(fd,65536)
    except OSError: break
    if not d: break
    out+=d
sys.stdout.buffer.write(out)
