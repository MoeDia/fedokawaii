"""keys.py — the keyboard as drawn and taught: his Redragon K617 Fizz, 61 keys, US layout; each key's place, width
and finger. (Its top-left key is Esc: with Fn the backtick, with Fn and Shift the tilde.)

Widths are in quarters of a key. Fingers: 0–3 the left hand's little, ring, middle and index, 4 its thumb;
5 the right thumb, 6–9 the right hand's index, middle, ring and little.
"""
NAMES = ('left little', 'left ring', 'left middle', 'left index', 'left thumb',
         'right thumb', 'right index', 'right middle', 'right ring', 'right little')

# name, width in quarters, its finger, what it shows, what it shows with shift
ROWS = (
    (('`', 4, 0, '`', '~'), ('1', 4, 0, '1', '!'), ('2', 4, 1, '2', '@'), ('3', 4, 2, '3', '#'), ('4', 4, 3, '4', '$'),
     ('5', 4, 3, '5', '%'), ('6', 4, 6, '6', '^'), ('7', 4, 6, '7', '&'), ('8', 4, 7, '8', '*'), ('9', 4, 8, '9', '('),
     ('0', 4, 9, '0', ')'), ('-', 4, 9, '-', '_'), ('=', 4, 9, '=', '+'), ('backspace', 8, 9, 'back', 'back')),
    (('tab', 6, 0, 'tab', 'tab'), ('q', 4, 0, 'q', 'Q'), ('w', 4, 1, 'w', 'W'), ('e', 4, 2, 'e', 'E'), ('r', 4, 3, 'r', 'R'),
     ('t', 4, 3, 't', 'T'), ('y', 4, 6, 'y', 'Y'), ('u', 4, 6, 'u', 'U'), ('i', 4, 7, 'i', 'I'), ('o', 4, 8, 'o', 'O'),
     ('p', 4, 9, 'p', 'P'), ('[', 4, 9, '[', '{'), (']', 4, 9, ']', '}'), ('\\', 6, 9, '\\', '|')),
    (('caps', 7, 0, 'caps', 'caps'), ('a', 4, 0, 'a', 'A'), ('s', 4, 1, 's', 'S'), ('d', 4, 2, 'd', 'D'), ('f', 4, 3, 'f', 'F'),
     ('g', 4, 3, 'g', 'G'), ('h', 4, 6, 'h', 'H'), ('j', 4, 6, 'j', 'J'), ('k', 4, 7, 'k', 'K'), ('l', 4, 8, 'l', 'L'),
     (';', 4, 9, ';', ':'), ("'", 4, 9, "'", '"'), ('enter', 9, 9, 'enter', 'enter')),
    (('lshift', 9, 0, 'shift', 'shift'), ('z', 4, 0, 'z', 'Z'), ('x', 4, 1, 'x', 'X'), ('c', 4, 2, 'c', 'C'), ('v', 4, 3, 'v', 'V'),
     ('b', 4, 3, 'b', 'B'), ('n', 4, 6, 'n', 'N'), ('m', 4, 6, 'm', 'M'), (',', 4, 7, ',', '<'), ('.', 4, 8, '.', '>'),
     ('/', 4, 9, '/', '?'), ('rshift', 11, 9, 'shift', 'shift')),
    (('lctrl', 5, 0, '', ''), ('lsuper', 5, 4, '', ''), ('lalt', 5, 4, '', ''), ('space', 25, 5, '', ''),
     ('ralt', 5, 5, '', ''), ('fn', 5, 5, '', ''), ('menu', 5, 9, '', ''), ('rctrl', 5, 9, '', '')),
)
HOME = {0: 'a', 1: 's', 2: 'd', 3: 'f', 6: 'j', 7: 'k', 8: 'l', 9: ';', 4: 'space', 5: 'space'}


def _table():
    place, chars = {}, {' ': ('space', False), '\n': ('enter', False)}
    for r, row in enumerate(ROWS):
        x = 0
        for name, width, finger, plain, shifted in row:
            place[name] = (x, r, width, finger, plain, shifted)
            if len(plain) == 1:
                chars[plain] = (name, False)
            if len(shifted) == 1:
                chars[shifted] = (name, True)
            x += width
    return place, chars


PLACE, CHARS = _table()


def needs(ch, thumb=5):
    """the keys a character takes: [(key, finger)], the letter's key first, then the opposite hand's shift.
    thumb: which thumb has the space bar this time. An unknown character needs nothing"""
    k = CHARS.get(ch)
    if k is None:
        return []
    name, shift = k
    finger = thumb if name == 'space' else PLACE[name][3]
    out = [(name, finger)]
    if name == '`':                     # (on the K617, Esc's key: Fn makes it the backtick)
        out.append(('fn', 5))
    if shift:
        out.append(('rshift', 9) if finger < 5 else ('lshift', 0))
    return out


def centre(name):
    x, r, w, _, _, _ = PLACE[name]
    return x * 5 + w * 5 // 2, r * 20 + 10
