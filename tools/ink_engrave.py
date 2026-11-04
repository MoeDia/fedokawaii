#!/usr/bin/env python3
"""tools/ink_engrave.py — one engraver's hand for the figures (tools/build-ink.py).

A picture's tones become lines of one ink: swelling parallel lines that ride the form (each line
displaced by a height field, as a banknote's portrait), a cross line where the tone falls, a
third in the deep shadows, a key line from an extended difference of Gaussians (XDoG) on top.
Whatever a figure came from, it leaves here in the same hand: one ink, one pitch, one weight.

engrave(tone, …) -> coverage in 0…1 (1 = ink), the size of `tone`, which is at 3 × the final size:
lines are cut at that size and reduced by box filter (reduce3): crisp edges, a grey pixel at most.
Needs numpy and scipy.
"""
import numpy as np
from scipy import ndimage as ndi


def blur(a, s):
    return ndi.gaussian_filter(a, s, mode="nearest")


def xdog(tone, s=1.2, k=1.6, p=18.0, eps=0.62, phi=40.0):
    """the key line: extended difference of Gaussians, 1 = ink"""
    a, b = blur(tone, s), blur(tone, s * k)
    d = (1 + p) * a - p * b
    e = np.where(d >= eps, 1.0, 1.0 + np.tanh(phi * (d - eps)))
    return np.clip(1 - e, 0, 1)


def lines(phase, width):
    """ink where the phase's fraction lies within `width` of a line's middle; width 0…1 of a pitch"""
    f = np.abs((phase % 1.0) - 0.5) * 2          # 0 at the middle of a line … 1 between lines
    return (f < np.clip(width, 0, 1)).astype(np.float32)


def engrave(tone, height=None, pitch=14.0, ride=30.0, angle=38.0, mirror_x=None, t2=0.60, t3=0.34,
            key_s=2.0, origin=(0, 0)):
    """tone at 3 × the final size; pitch and ride in those pixels. mirror_x: a frontal figure's middle,
    its two halves hatch in mirror. origin: where this part of the plate lies on the whole, so a
    part cut alone lines up with the rest"""
    h, w = tone.shape
    yy, xx = np.mgrid[origin[1]:origin[1] + h, origin[0]:origin[0] + w].astype(np.float32)
    if height is None:
        height = blur(tone, pitch * 1.2)
    th = np.deg2rad(angle)
    x = xx if mirror_x is None else np.abs(xx - mirror_x)
    c1 = (x * np.cos(th) + yy * np.sin(th)) / pitch + ride * height / pitch
    c2 = (x * np.cos(th + np.pi / 2.6) + yy * np.sin(th + np.pi / 2.6)) / (pitch * 1.05) - ride * .6 * height / pitch
    c3 = (x * np.cos(th - np.pi / 3.3) + yy * np.sin(th - np.pi / 3.3)) / (pitch * .9)
    t = np.clip(tone, 0, 1)
    # the first line swells with the dark: at paper it thins to nothing
    ink = lines(c1, np.clip((1 - t) * 1.05, 0, .92))
    ink = np.maximum(ink, lines(c2, np.clip((t2 - t) / t2 * .85, 0, .85)))
    ink = np.maximum(ink, lines(c3, np.clip((t3 - t) / t3 * .9, 0, .9)))
    return np.maximum(ink, xdog(tone, s=key_s)).astype(np.float32)


def reduce3(a, n=3):
    """box filter to the final size"""
    h, w = a.shape[:2]
    h, w = h - h % n, w - w % n
    a = a[:h, :w]
    if a.ndim == 2:
        return a.reshape(h // n, n, w // n, n).mean((1, 3))
    return a.reshape(h // n, n, w // n, n, -1).mean((1, 3))
