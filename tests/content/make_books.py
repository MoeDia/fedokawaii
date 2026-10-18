#!/usr/bin/env python3
"""make_books.py KIND OUT [ARG…] — small real files for the books and clipboard tests, made
from nothing but the standard library (no ImageMagick, no PIL):

  png OUT W H RRGGBB [RRGGBB]     a picture; with a second colour, a centred block of it
                                  (half the width and height) on the first
  pdf OUT PAGES [RRGGBB]          a PDF of PAGES pages, 100×150 pt; the first page coloured
  epub OUT COVER                  an EPUB; COVER: meta (EPUB 2 <meta name="cover">),
                                  property (EPUB 3 cover-image), named (just a file called
                                  cover.jpg… here .png), encoded (a meta cover whose
                                  href has %20 for a space), none
  cbz OUT NAME…                   a comic book: each NAME a picture (a .txt NAME: text)
  sqlite DB FILE PAGE WHEN …      zathura's bookmarks.sqlite: a fileinfo row per triple
"""
import os, sqlite3, struct, sys, zipfile, zlib


def png_bytes(w, h, c1, c2=None):
    a = bytes.fromhex(c1); b = bytes.fromhex(c2) if c2 else a
    rows = []
    for y in range(h):
        inner = h // 4 <= y < h - h // 4
        rows.append(b"\0" + b"".join(b if inner and w // 4 <= x < w - w // 4 else a for x in range(w)))
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


def pdf_bytes(pages, colour="d0583a"):
    r, g, b = (int(colour[i:i + 2], 16) / 255 for i in (0, 2, 4))
    objs = ["<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [%s] /Count %d >>" % (" ".join("%d 0 R" % (3 + 2 * i) for i in range(pages)), pages)]
    for i in range(pages):
        draw = ("%.3f %.3f %.3f rg 10 10 80 130 re f" % (r, g, b)) if i == 0 else "0 0 0 rg 40 70 20 10 re f"
        objs.append("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 150] /Contents %d 0 R >>" % (4 + 2 * i))
        objs.append("<< /Length %d >>\nstream\n%s\nendstream" % (len(draw), draw))
    out, offs = bytearray(b"%PDF-1.4\n"), []
    for n, o in enumerate(objs, 1):
        offs.append(len(out)); out += b"%d 0 obj\n%s\nendobj\n" % (n, o.encode())
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offs: out += b"%010d 00000 n \n" % o
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    return bytes(out)


def epub(out, cover):
    pic = png_bytes(60, 90, "5f7fa0", "e3b866")
    meta = '<meta name="cover" content="cov"/>' if cover in ("meta", "encoded") else ""
    prop = ' properties="cover-image"' if cover == "property" else ""
    items = '<item id="text" href="text.xhtml" media-type="application/xhtml+xml"/>'
    if cover in ("meta", "property"):
        items += '<item id="cov" href="images/front.png" media-type="image/png"%s/>' % prop
    if cover == "encoded":                 # (an href is a URL: a space in the name is %20)
        items += '<item id="cov" href="images/front%20page.png" media-type="image/png"/>'
    opf = ('<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
           '<metadata>%s</metadata><manifest>%s</manifest><spine><itemref idref="text"/></spine></package>'
           % (meta, items))
    with zipfile.ZipFile(out, "w") as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr("META-INF/container.xml", '<?xml version="1.0"?><container><rootfiles>'
                   '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
                   '</rootfiles></container>')
        z.writestr("OEBPS/content.opf", opf)
        z.writestr("OEBPS/text.xhtml", "<html><body><p>once upon a time</p></body></html>")
        if cover in ("meta", "property"): z.writestr("OEBPS/images/front.png", pic)
        if cover == "named": z.writestr("OEBPS/images/Cover.png", pic)
        if cover == "encoded": z.writestr("OEBPS/images/front page.png", pic)


def main(a):
    kind, out = a[0], a[1]
    if kind == "png":
        open(out, "wb").write(png_bytes(int(a[2]), int(a[3]), a[4], a[5] if len(a) > 5 else None))
    elif kind == "pdf":
        open(out, "wb").write(pdf_bytes(int(a[2]), a[3] if len(a) > 3 else "d0583a"))
    elif kind == "epub":
        epub(out, a[2])
    elif kind == "cbz":
        with zipfile.ZipFile(out, "w") as z:
            for i, n in enumerate(a[2:]):
                z.writestr(n, b"just text" if n.endswith(".txt") else png_bytes(40, 60, "8e9a5b", "%02x0000" % (40 * i % 256)))
    elif kind == "sqlite":
        con = sqlite3.connect(out)
        con.execute("CREATE TABLE IF NOT EXISTS fileinfo (file TEXT PRIMARY KEY, page INTEGER, offset INTEGER,"
                    " zoom FLOAT, rotation INTEGER, pages_per_row INTEGER, first_page_column TEXT,"
                    " position_x FLOAT, position_y FLOAT, time TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")
        rest = a[2:]
        for i in range(0, len(rest), 3):
            con.execute("INSERT OR REPLACE INTO fileinfo (file, page, time) VALUES (?, ?, ?)",
                        (os.fsdecode(os.fsencode(rest[i])), int(rest[i + 1]), rest[i + 2]))
        con.commit(); con.close()
    else:
        sys.exit("make_books: unknown kind " + kind)


if __name__ == "__main__":
    main(sys.argv[1:])
