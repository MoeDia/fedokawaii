"""tests/lib/rar4.py ARCHIVE NAME=TEXT… — a RAR 4 archive, stored (no compression), for the tests:
no `rar` exists on Fedora (only RPM Fusion's unrar, which reads), and 7-Zip there has no RAR at all.
The format (RARLAB's technote for 4.x): the marker, the main header, a file header and its bytes for
each NAME, the end header; every header's CRC the low 16 bits of CRC-32 from its type byte on."""
import struct
import sys
import zlib


def block(kind, flags, body):
    head = struct.pack("<BHH", kind, flags, 7 + len(body)) + body
    return struct.pack("<H", zlib.crc32(head) & 0xFFFF) + head


def entry(name, data):
    raw = name.encode()
    body = struct.pack("<IIBIIBBHI", len(data), len(data), 3, zlib.crc32(data), 0x5A210000, 20, 0x30,
                       len(raw), 0o100644) + raw       # (host 3, Unix: the mode as it is)
    return block(0x74, 0x8000, body) + data            # (0x8000: the data follows the header)


def main():
    parts = [b"Rar!\x1a\x07\x00", block(0x73, 0, b"\0" * 6)]
    for arg in sys.argv[2:]:
        name, _, text = arg.partition("=")
        parts.append(entry(name, text.encode()))
    parts.append(block(0x7B, 0x4000, b""))
    with open(sys.argv[1], "wb") as f:
        f.write(b"".join(parts))


if __name__ == "__main__":
    main()
