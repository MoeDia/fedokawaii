#!/usr/bin/env python3
"""tools/build-typing.py — the typing app's word list, letter patterns and passages, counted and cut from
public-domain books (Project Gutenberg), so nothing it types has a licence of its own.

    python3 -I tools/build-typing.py PG_DIR [OUT_DIR]

PG_DIR holds N.txt for every book below (https://www.gutenberg.org/cache/epub/N/pgN.txt); a book whose
SHA-256 differs stops it. OUT_DIR defaults to the app's own folder. Writes:
    words.txt     the 6000 commonest plain words, commonest first
    patterns.txt  the 60 commonest letter pairs and 40 triples inside words, each with words holding it
    passages.txt  tea, kwaidan and bushido, cut at sentence ends: "BOOK<TAB>TEXT", hardest last
Exit 0 · 1 a book missing or changed · 2 misuse.
"""
import collections
import hashlib
import os
import re
import sys

# the books the words are counted in: plain prose of many kinds, nothing older than the 19th century
COUNTED = {
    '769': 'a7464287f9b431a55ff5', '1210': '7a65d208d24f0cae80af', '12096': 'ceb5f526b47fa46bfa7f',
}
MORE = '1661 35 36 74 11 1342 84 345 236 205 1228 76 120 2701 98 1260 145'.split()
PASSAGES = {'769': 'tea', '1210': 'kwaidan', '12096': 'bushido'}
# what plain words should not hold: the old second person, and what no one wants drilled
LEFT_OUT = set('thou thee thy thine hath doth shalt wilt art ye nay sir madam mrs mr dr st ii iii iv vi vii '
               'negro negroes nigger slave slaves kill killed rape whore bitch damn hell ass asses sex breast breasts '
               'naked whip murder murdered murderer suicide corpse torture savage savages hanged bloody poison wretch drunk'.split())
LEFT_OUT_TEXT = re.compile(r'\b(suicide|hara-?kiri|seppuku|disembowel\w*|entrails|concubines?|negro\w*|savages?|coolies?|rape\w*|ravish\w*|'
                           r'whores?|harlots?|prostitut\w*|hanged|corpses?|mutilat\w*|tortur\w*|behead\w*|decapitat\w*|severed|slaughter\w*|massacre\w*)\b', re.I)
NORM = {'‘': "'", '’': "'", '“': '"', '”': '"', '—': ' - ', '–': '-', '…': '...',
        '\xa0': ' ', 'ō': 'o', 'ū': 'u', 'Ō': 'O', 'Ū': 'U', '\xe9': 'e', '\xe8': 'e', '\xe0': 'a',
        '\xe2': 'a', '\xe4': 'a', '\xef': 'i', '\xf6': 'o', '\xfc': 'u', '\xe6': 'ae', '--': ' - '}


def body(path):
    t = open(path, encoding='utf-8', errors='replace').read().replace('\r\n', '\n')
    a, b = re.search(r'\*\*\* START OF.*?\*\*\*', t), re.search(r'\*\*\* END OF', t)
    return t[a.end():b.start()]


def plain(par):
    par = re.sub(r'\[[^\]]*\]', '', re.sub(r'\s+', ' ', par)).strip()
    for a, b in NORM.items():
        par = par.replace(a, b)
    return re.sub(r' +', ' ', re.sub(r'(?<=[a-z]) - (?=[A-Za-z])', ' - ', par))


def sentences(par):
    return re.findall(r'[^.!?]+(?:[.!?]+["\')]*|$)\s*', par)


def fit(s):
    """a passage typed as printed: plain letters, no odd signs, its quotes closed"""
    return (s.isascii() and s[:1].isupper() and s[-1] in '.!?"' and not re.search(r'[\d\[\]*_#<>|/\\~^]', s)
            and not re.search(r'[A-Z]{3,}', s) and s.count('"') % 2 == 0 and s.count('(') == s.count(')')
            and not re.match(r'(Chapter|Footnote|Note|Illustration|Copyright|Produced)\b', s))


def cut(par, low=180, high=520):
    """the paragraph's sentences gathered into passages of low to high characters"""
    out, cur = [], ''
    for s in sentences(par):
        if cur and len(cur) + len(s) > high:
            out.append(cur.strip())
            cur = ''
        cur += s
    out.append(cur.strip())
    return [p for p in out if low <= len(p) <= high and fit(p)]


def main(argv):
    if not argv or len(argv) > 2:
        print(__doc__, file=sys.stderr)
        return 2
    pg = argv[0]
    out = argv[1] if len(argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                                     'configs/home/.local/lib/fedokawaii/kawatype')
    words, lower, books = collections.Counter(), collections.Counter(), collections.defaultdict(set)
    for n in [*COUNTED, *MORE]:
        path = os.path.join(pg, n + '.txt')
        if not os.path.exists(path):
            print(f'build-typing: no {path}', file=sys.stderr)
            return 1
        data = open(path, 'rb').read()
        if n in COUNTED and not hashlib.sha256(data).hexdigest().startswith(COUNTED[n]):
            print(f'build-typing: {path} is not the file this was built from', file=sys.stderr)
            return 1
        for w in re.findall(r"[A-Za-z]+(?:'[a-z]+)?", plain(body(path))):
            k = w.lower()
            words[k] += 1
            lower[k] += w == k
            books[k].add(n)
    # plain words: mostly written in lower case (no names), in several books, of letters only
    keep = [w for w, c in words.most_common() if lower[w] > 0.6 * c and len(books[w]) >= 5 and w.isalpha()
            and w not in LEFT_OUT and (len(w) > 1 or w in 'ai')]
    keep = keep[:6000]
    rank = {w: i for i, w in enumerate(keep)}
    with open(os.path.join(out, 'words.txt'), 'w') as f:
        f.write('\n'.join(keep) + '\n')
    # patterns: pairs and triples inside words, weighted by how often the word is typed
    grams = {2: collections.Counter(), 3: collections.Counter()}
    for w in keep:
        for n, c in grams.items():
            for i in range(len(w) - n + 1):
                c[w[i:i + n]] += words[w]
    with open(os.path.join(out, 'patterns.txt'), 'w') as f:
        for n, top in ((2, 60), (3, 40)):
            for g, _ in grams[n].most_common(top):
                hold = sorted((w for w in keep if g in w and len(w) >= n + 1), key=rank.get)[:24]
                f.write(g + '\t' + ' '.join(hold) + '\n')
    # passages: easiest first, by length and how rare their words are
    passages = []
    for n, book in PASSAGES.items():
        for par in re.split(r'\n\s*\n', body(os.path.join(pg, n + '.txt'))):
            for p in cut(plain(par)):
                if LEFT_OUT_TEXT.search(p):
                    continue
                ws = [w.lower() for w in re.findall(r"[A-Za-z]+", p)]
                rare = sum(rank.get(w, 8000) for w in ws) / max(len(ws), 1)
                passages.append((len(p) / 500 + rare / 1500 + len(re.findall(r"[,;:'\"()-]", p)) / max(len(p), 1) * 8, book, p))
    passages.sort()
    with open(os.path.join(out, 'passages.txt'), 'w') as f:
        for _, book, p in passages:
            f.write(book + '\t' + p + '\n')
    print(f'{len(keep)} words, {sum(1 for _ in open(os.path.join(out, "patterns.txt")))} patterns, {len(passages)} passages')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
