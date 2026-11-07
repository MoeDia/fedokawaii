"""lib/lessonpage.py — a standard-2 lesson as one calm local page (docs/lesson-standard.md, "The page").

    import lessonpage; html = lessonpage.render(lesson, css)

lesson: lessons.parse()'s dict of a standard-2 lesson; css: the theme's lesson.css (both moods, written and
measured for WCAG AA by tools/build-themes.py), put inline so the page is one file and needs no network.
Pictures: a ```picture fence holding <svg> is drawn as it is (its inks: class ink, soft, line, mark); parts
with data-step="N" appear one step at a time, on a click on the picture or on → / Space (← goes back), never
by themselves. Any other picture is a drawing in text. Keys [[Super+R]] are keycaps, as the panel's."""
import html
import re

SECTIONS = (("remember", "remember"), ("example", "an example"), ("idea", "the idea"),
            ("exercise", "your turn"), ("check", "the check"), ("behind", "behind the scenes"),
            ("mistakes", "common mistakes"), ("quiz", "the quiz"), ("next", "next"), ("checked", "checked against"))
KEYS = re.compile(r"\[\[([^\]\s]+)\]\]")
TOKEN = re.compile(r"(`+)(.+?)\1|\*\*(.+?)\*\*|(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])", re.S)
CAP_NAME = {"escape": "esc", "return": "enter", "backspace": "bksp", "delete": "del"}
LEVELS = ("Warm-up:", "Real:", "Stretch:")
HINTS = ("a nudge", "a bigger nudge")

SCRIPT = """(function(){
var figs=[].slice.call(document.querySelectorAll('figure.steps'));
function show(f,n){var max=+f.dataset.max;n=Math.max(0,Math.min(n,max));f.dataset.at=n;
 f.querySelectorAll('[data-step]').forEach(function(e){e.classList.toggle('on',+e.dataset.step<=n)});
 f.querySelector('.count').textContent=n+' / '+max;}
figs.forEach(function(f){var max=0;f.querySelectorAll('[data-step]').forEach(function(e){max=Math.max(max,+e.dataset.step)});
 f.dataset.max=max;show(f,0);f.addEventListener('click',function(){show(f,+f.dataset.at<max?+f.dataset.at+1:0)});});
function near(){var best=null,d=1e9;figs.forEach(function(f){var r=f.getBoundingClientRect(),c=Math.abs(r.top+r.height/2-innerHeight/2);
 if(r.bottom>0&&r.top<innerHeight&&c<d){d=c;best=f}});return best;}
addEventListener('keydown',function(e){if(e.ctrlKey||e.altKey||e.metaKey)return;var f=near();if(!f)return;
 if(e.key==='ArrowRight'||e.key===' '){show(f,+f.dataset.at+1);e.preventDefault();}
 else if(e.key==='ArrowLeft'){show(f,+f.dataset.at-1);e.preventDefault();}});
})();"""


def esc(s):
    return html.escape(s, quote=False)


def keycaps(chord):
    """[[Super+Shift+R]] as the panel's keycaps: one cap a key, lower case words, the letter as written"""
    caps = []
    for k in chord.split("+"):
        k = k.lower() if len(k) > 1 else k
        caps.append(f"<span>{esc(CAP_NAME.get(k, k))}</span>")
    return f"<kbd>{''.join(caps)}</kbd>"


def inline(s):
    """a paragraph's words: `code`, **strong**, *aside*, [[keys]]; everything else escaped"""
    out, at = [], 0
    for m in TOKEN.finditer(s):
        out.append(words(s[at:m.start()]))
        if m[1]:
            out.append(f"<code>{esc(m[2])}</code>")
        elif m[3] is not None:
            out.append(f"<strong>{inline(m[3])}</strong>")
        else:
            out.append(f"<em>{inline(m[4])}</em>")
        at = m.end()
    out.append(words(s[at:]))
    return "".join(out)


def words(s):
    out, at = [], 0
    for m in KEYS.finditer(s):
        out.append(esc(s[at:m.start()]) + keycaps(m[1]))
        at = m.end()
    return "".join(out) + esc(s[at:])


def blocks(text):
    """a section's text as ("p", words) and ("fence", info, body), paragraphs joined"""
    out, para, fence = [], [], None
    for row in text.split("\n"):
        if fence is not None:
            if row == "```":
                out.append(("fence", fence[0], "\n".join(fence[1])))
                fence = None
            else:
                fence[1].append(row)
        elif row.startswith("```"):
            if para:
                out.append(("p", " ".join(para)))
                para = []
            fence = (row[3:].strip(), [])
        elif row.strip():
            para.append(row.strip())
        elif para:
            out.append(("p", " ".join(para)))
            para = []
    if para:
        out.append(("p", " ".join(para)))
    return out


def code(lang, body, cls="code"):
    label = f'<span class="lang">{esc(lang)}</span>' if lang else ""
    return f'<div class="{cls}">{label}<pre>{esc(body)}</pre></div>'


def picture(body):
    if body.lstrip().startswith("<svg"):
        if "data-step" in body:
            return f'<figure class="steps" tabindex="0">{body.strip()}<figcaption class="count"></figcaption></figure>'
        return f"<figure>{body.strip()}</figure>"
    return f'<figure><pre class="drawing">{esc(body)}</pre></figure>'


def section_body(key, text, lesson):
    out, hint = [], 0
    for b in blocks(text):
        if b[0] == "p":
            p = b[1]
            level = next((lv for lv in LEVELS if p.startswith(lv + " ")), None)
            if key == "exercise" and level:
                out.append(f'<p class="level"><b>{esc(level[:-1])}</b> {inline(p[len(level) + 1:])}</p>')
            else:
                out.append(f"<p>{inline(p)}</p>")
            continue
        info, body = b[1], b[2]
        kind = info.split(" ")[0]
        if kind == "term":
            out.append(f'<dl class="term"><dt>{esc(info[5:].strip())}</dt><dd>{inline(body.strip())}</dd></dl>')
        elif kind == "hint":
            out.append(f'<details class="hint"><summary>{HINTS[min(hint, 1)]}</summary><p>{inline(body.strip())}</p></details>')
            hint += 1
        elif kind == "output":
            out.append(code("what it printed", body, "code output"))
        elif kind == "picture":
            out.append(picture(body))
        elif kind == "peek":
            out.append(code("peek", body, "code peek"))
        elif kind in ("quiz", "check"):
            continue
        else:
            out.append(code(info, body))
    return "".join(out)


def quiz(pairs):
    return "".join(f'<details class="q"><summary>{inline(q)}</summary><p>{inline(a)}</p></details>' for q, a in pairs)


def render(lesson, css):
    """the page's html: the lesson's sections in the standard's order, one column"""
    if lesson.get("standard") != 2:
        raise ValueError(f"{lesson.get('id')}: only a standard-2 lesson has a page")
    parts = []
    for key, head in SECTIONS:
        if key == "remember":
            if not lesson["remember"]:
                continue
            body = quiz(lesson["remember"])
        elif key == "check":
            c = lesson["check"]
            body = f"<p>{inline(c['ask'])}</p>" if c.get("kind") == "ask" else \
                "<p>kawa-learn runs it when you are done: Enter at the lesson's end.</p>"
        elif key == "mistakes":
            body = "<ul>" + "".join(f"<li>{inline(m)}</li>" for m in lesson["mistakes"]) + "</ul>"
        elif key == "quiz":
            body = quiz(lesson["quiz"])
        elif key == "next":
            body = f"<p>{inline(lesson['next'])}</p>"
        elif key == "checked":
            body = "<ul class=\"src\">" + "".join(
                f'<li>{esc(doc)}, {esc(ver)}: <a href="{html.escape(url)}">{esc(url)}</a></li>'
                for doc, ver, url in lesson["checked"]) + "</ul>"
        else:
            body = section_body(key, lesson[key], lesson)
        parts.append(f'<section class="{key}"><h2>{head}</h2>{body}</section>')
    return (f'<!doctype html>\n<html lang="en"><meta charset="utf-8"><meta name="color-scheme" content="light dark">'
            f"<title>{esc(lesson['title'])}</title><style>{css}</style>\n"
            f'<main><header><p class="part">part {lesson["part"]} · {lesson["minutes"]} minutes</p>'
            f"<h1>{inline(lesson['title'])}</h1></header>\n" + "\n".join(parts) +
            f"\n</main><script>{SCRIPT}</script>\n")
