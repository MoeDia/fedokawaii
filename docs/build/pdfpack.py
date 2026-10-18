#!/usr/bin/env python3
"""pdfpack.py IN OUT — lossless: every RGB/gray 8-bit image re-compressed with PNG row
predictors (the handbook's pictures are whole-number NEAREST enlargements, so most rows
repeat the one above: the Up/Paeth filters turn them into zeros), then qpdf-style object
streams. Pixels are bit-for-bit the same."""
import sys, zlib
import numpy as np
import pikepdf

def png_filter(a, bpp):
    """a: H x (W*bpp) uint8 → PNG-filtered bytes: per row the filter of None/Sub/Up/Average/
    Paeth whose output has the smallest sum of signed magnitudes (libpng's heuristic)."""
    x = a.astype(np.int16)
    up = np.zeros_like(x); up[1:] = x[:-1]
    left = np.zeros_like(x); left[:, bpp:] = x[:, :-bpp]
    ul = np.zeros_like(x); ul[1:, bpp:] = x[:-1, :-bpp]
    p = left + up - ul
    pa, pb, pc = np.abs(p - left), np.abs(p - up), np.abs(p - ul)
    paeth = np.where((pa <= pb) & (pa <= pc), left, np.where(pb <= pc, up, ul))
    cands = [x, x - left, x - up, x - ((left + up) >> 1), x - paeth]
    cands = [(c & 0xFF).astype(np.uint8) for c in cands]
    score = np.stack([np.abs(c.astype(np.int8).astype(np.int16)).sum(1) for c in cands])   # 5 x H
    best = score.argmin(0)
    out = np.empty((a.shape[0], a.shape[1] + 1), np.uint8)
    out[:, 0] = best
    for f in range(5):
        rows = best == f
        out[rows, 1:] = cands[f][rows]
    return out.tobytes()

def main(src, dst):
    pdf = pikepdf.open(src)
    before = after = 0
    for obj in pdf.objects:
        if not isinstance(obj, pikepdf.Stream) or obj.get('/Subtype') != '/Image':
            continue
        if obj.get('/BitsPerComponent') != 8 or obj.get('/Filter') not in (pikepdf.Name.FlateDecode, None):
            continue
        if '/DecodeParms' in obj:
            continue
        cs = obj.get('/ColorSpace')
        if isinstance(cs, pikepdf.Array) and len(cs) == 2 and cs[0] == '/ICCBased':
            colors = int(cs[1].get('/N', 0)) or None
        else:
            colors = 3 if cs == '/DeviceRGB' else 1 if cs == '/DeviceGray' else None
        if colors is None:
            continue
        W, H = int(obj.Width), int(obj.Height)
        raw = obj.read_bytes()
        if len(raw) != W * H * colors:
            continue
        a = np.frombuffer(raw, np.uint8).reshape(H, W * colors)
        data = zlib.compress(png_filter(a, colors), 9)
        old = len(obj.read_raw_bytes())
        before += old
        if len(data) < old:
            obj.write(data, filter=pikepdf.Name.FlateDecode,
                      decode_parms=pikepdf.Dictionary(Predictor=15, Colors=colors, BitsPerComponent=8, Columns=W))
            after += len(data)
        else:
            after += old
    pdf.save(dst, compress_streams=True, object_stream_mode=pikepdf.ObjectStreamMode.generate,
             recompress_flate=False)
    print(f"images {before // 1024} KB → {after // 1024} KB")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
