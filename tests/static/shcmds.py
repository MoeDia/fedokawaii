#!/usr/bin/env python3
"""tests/static/shcmds.py — which programs a piece of shell runs, read the way bash reads it.

    python3 shcmds.py FILE…          one line per program a shell file runs: LINE<TAB>NAME
    python3 shcmds.py -c 'STRING'    the same for a command line (waybar's exec, a SHCMD…)

A small lexer and parser, not a shell: enough of bash's grammar to tell a program from its
arguments — quotes, $( ) and ` ` (read again inside), <( ), here-documents, case patterns,
[[ … =~ regex ]], (( )), function definitions, assignments — and the programs that run
another program (setsid -f X, timeout 3 X, env A=1 X, sudo X, kawa-term X, kawa-term --float … -- X, foot -- X,
sh -c 'X', swayidle timeout 600 'X', trap 'X', find -exec X, xargs X …).

A name it cannot know (a variable, "$@") is left out. Names checked with command -v,
type -P or hash in the same piece of shell are marked "guarded" (the caller copes when the
program is absent): LINE<TAB>NAME<TAB>guarded.
"""
import re
import sys

BUILTINS = set("""
: . [ alias bg bind break builtin caller cd command compgen complete compopt continue
declare dirs disown echo enable eval exec exit export false fc fg getopts hash help history
jobs kill let local logout mapfile popd printf pushd pwd read readarray readonly return set
shift shopt source suspend test times trap true type typeset ulimit umask unalias unset wait
""".split())
KEYWORDS = set("if then else elif fi case esac for select while until do done in function "
               "time { } ! [[ ]] coproc".split())
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=")
OPS = ["&&", "||", ";;&", ";;", ";&", "|&", "|", "&", ";", "(", ")"]
REDIRS = ["<<<", "<<-", "<<", "<>", "<&", ">&", ">>", ">|", "&>>", "&>", "<", ">"]
META = set(" \t\n;&|<>()")


class Tok:
    __slots__ = ("kind", "text", "lit", "line", "body")

    def __init__(self, kind, text, lit, line, body=None):
        self.kind, self.text, self.lit, self.line, self.body = kind, text, lit, line, body

    def __repr__(self):
        return f"{self.kind}:{self.text!r}"


class Sink:
    """What a whole piece of shell runs: calls (line, name) and the guarded names."""

    def __init__(self):
        self.calls, self.guards, self.funcs = [], set(), set()


class Lexer:
    def __init__(self, text, sink, pos=0, line=1, stop_paren=False):
        self.s, self.i, self.line, self.sink = text, pos, line, sink
        self.stop_paren, self.toks, self.heredocs = stop_paren, [], []
        self.depth = self.case = 0
        self.dbracket = self.regex_next = False

    # ── helpers ──────────────────────────────────────────────────────────────
    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def sub(self, start, line):
        """$( … ) or <( … ) from START: read it as a program of its own; returns the end."""
        lx = Lexer(self.s, self.sink, start, line, stop_paren=True)
        lx.run()
        Parser(lx.toks, self.sink).run()
        return lx.i, lx.line

    def backtick(self):
        """` … ` at self.i (just past the opening one): the inside, unescaped, read again."""
        j, out = self.i, []
        while j < len(self.s) and self.s[j] != "`":
            if self.s[j] == "\\" and j + 1 < len(self.s):
                out.append(self.s[j + 1]); j += 2; continue
            out.append(self.s[j]); j += 1
        inner = "".join(out)
        run_string(inner, self.sink, self.line)
        self.line += inner.count("\n")
        self.i = j + 1

    def arith(self, j, opening):
        """from J, just past OPENING parens: to just past the matching ))."""
        d = opening
        while j < len(self.s) and d:
            c = self.s[j]
            if c == "(":
                d += 1
            elif c == ")":
                d -= 1
            elif c == "\n":
                self.line += 1
            j += 1
        return j

    def dollar(self):
        """at a $: returns True when it was an expansion (not a plain literal $)."""
        nxt = self.peek(1)
        if nxt == "(":
            if self.peek(2) == "(":
                self.i = self.arith(self.i + 3, 2)
            else:
                self.i, self.line = self.sub(self.i + 2, self.line)
            return True
        if nxt == "{":
            self.i += 2
            self.braced()
            return True
        if nxt == "'":                       # $'…': ANSI-C quoting, a literal
            self.i += 2
            while self.i < len(self.s) and self.s[self.i] != "'":
                self.i += 2 if self.s[self.i] == "\\" else 1
            self.i += 1
            return False
        if nxt == '"':                       # $"…": a translated string, a literal here
            self.i += 1
            return self.dquote()
        if nxt and (nxt.isalnum() or nxt in "_@*#?$!-"):
            self.i += 2
            if nxt.isalpha() or nxt == "_":
                while self.i < len(self.s) and (self.s[self.i].isalnum() or self.s[self.i] == "_"):
                    self.i += 1
            return True
        self.i += 1
        return False

    def braced(self):
        """inside ${ … }: to just past its }, reading what runs inside."""
        while self.i < len(self.s):
            c = self.s[self.i]
            if c == "}":
                self.i += 1
                return
            if c == "\\":
                self.i += 2
            elif c == "'":
                j = self.s.find("'", self.i + 1)
                self.i = len(self.s) if j < 0 else j + 1
            elif c == '"':
                self.dquote()
            elif c == "$":
                self.dollar()
            elif c == "`":
                self.i += 1
                self.backtick()
            else:
                if c == "\n":
                    self.line += 1
                self.i += 1

    def dquote(self):
        """at a ": to just past its closing ". True when anything inside expands."""
        self.i += 1
        exp = False
        while self.i < len(self.s):
            c = self.s[self.i]
            if c == '"':
                self.i += 1
                return exp
            if c == "\\":
                if self.peek(1) == "\n":
                    self.line += 1
                self.i += 2
            elif c == "$":
                exp = self.dollar() or exp
            elif c == "`":
                self.i += 1
                self.backtick()
                exp = True
            else:
                if c == "\n":
                    self.line += 1
                self.i += 1
        return exp

    # ── words ────────────────────────────────────────────────────────────────
    def word(self):
        start, line, exp, lit = self.i, self.line, False, []
        regex = self.regex_next
        self.regex_next = False
        pdepth = 0
        while self.i < len(self.s):
            c = self.s[self.i]
            if regex:
                if c in " \t\n" and pdepth == 0:
                    break
                if c == "(":
                    pdepth += 1
                elif c == ")":
                    if pdepth == 0:
                        break
                    pdepth -= 1
            elif c in META:
                # extglob @( ) ?( ) *( ) +( ) !( ) and an array's ( … ) belong to the word
                if c == "(" and lit and lit[-1] in "@?*+!":
                    self.i = self.skip_parens(self.i + 1)
                    lit.append("(…)")
                    continue
                if c == "(" and ASSIGN.match("".join(lit)) and "".join(lit).endswith("="):
                    lx = Lexer(self.s, self.sink, self.i + 1, self.line, stop_paren=True)
                    lx.run()
                    self.i, self.line = lx.i, lx.line
                    exp = True
                    continue
                if c in "<>" and self.dbracket:
                    lit.append(c); self.i += 1
                    continue
                break
            if c == "\\":
                if self.peek(1) == "\n":
                    self.i += 2; self.line += 1
                    continue
                lit.append(self.peek(1)); self.i += 2
            elif c == "'":
                j = self.s.find("'", self.i + 1)
                j = len(self.s) if j < 0 else j
                part = self.s[self.i + 1:j]
                self.line += part.count("\n")
                lit.append(part); self.i = j + 1
            elif c == '"':
                j0 = self.i
                if self.dquote():
                    exp = True
                lit.append(self.s[j0 + 1:self.i - 1])
            elif c == "$":
                j0 = self.i
                if self.dollar():
                    exp = True
                lit.append(self.s[j0:self.i])
            elif c == "`":
                self.i += 1
                self.backtick()
                exp = True
            else:
                lit.append(c); self.i += 1
        text = self.s[start:self.i]
        value = "".join(lit)
        return Tok("w", text, None if exp else value, line)

    def skip_parens(self, j):
        d = 1
        while j < len(self.s) and d:
            if self.s[j] == "(":
                d += 1
            elif self.s[j] == ")":
                d -= 1
            j += 1
        return j

    # ── here-documents ───────────────────────────────────────────────────────
    def heredoc_bodies(self):
        """at the start of the line after one with << : each body, up to its delimiter."""
        for tok, delim, strip, quoted in self.heredocs:
            lines = []
            while self.i < len(self.s):
                end = self.s.find("\n", self.i)
                end = len(self.s) if end < 0 else end
                ln = self.s[self.i:end]
                self.i = min(end + 1, len(self.s)); self.line += 1
                if (ln.lstrip("\t") if strip else ln) == delim:
                    break
                lines.append(ln)
            body = "\n".join(lines)
            tok.body = body
            if not quoted:                   # its $( ) and ` ` run
                scan_expansions(body, self.sink, tok.line + 1)
        self.heredocs = []

    # ── the token stream ─────────────────────────────────────────────────────
    def emit(self, kind, text, lit=None):
        t = Tok(kind, text, lit, self.line)
        self.toks.append(t)
        return t

    def run(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t":
                self.i += 1
                continue
            if c == "\\" and self.peek(1) == "\n":
                self.i += 2; self.line += 1
                continue
            if c == "#":
                j = s.find("\n", self.i)
                self.i = len(s) if j < 0 else j
                continue
            if c == "\n":
                self.emit("op", "\n")
                self.i += 1; self.line += 1
                if self.heredocs:
                    self.heredoc_bodies()
                continue
            if s.startswith("((", self.i) and (not self.toks or self.toks[-1].kind == "op"
                                               or self.toks[-1].lit in KEYWORDS):
                self.i = self.arith(self.i + 2, 2)
                self.emit("w", "((…))")
                continue
            if c in "<>" and self.peek(1) == "(":            # <( … ) >( … )
                self.i, self.line = self.sub(self.i + 2, self.line)
                self.emit("w", "<(…)")
                continue
            if c in "<>&" and not self.dbracket:
                r = next((r for r in REDIRS if s.startswith(r, self.i)), None)
                if r:
                    self.i += len(r)
                    t = self.emit("redir", r)
                    if r in ("<<", "<<-"):
                        while self.peek() in " \t":
                            self.i += 1
                        w = self.word()
                        quoted = any(q in w.text for q in "'\"\\")
                        delim = w.lit if w.lit is not None else re.sub(r"['\"\\]", "", w.text)
                        self.toks.append(w)
                        self.heredocs.append((t, delim, r == "<<-", quoted))
                    continue
            op = next((o for o in OPS if s.startswith(o, self.i)), None)
            if op:
                self.i += len(op)
                if op == "(":
                    self.depth += 1
                elif op == ")":
                    if self.depth:
                        self.depth -= 1
                    elif self.case:
                        pass                 # a case pattern's )
                    elif self.stop_paren:
                        return
                self.emit("op", op)
                continue
            # a word; an fd number right before < or > belongs to the redirection
            m = re.match(r"\d+(?=[<>])|\{[A-Za-z_][A-Za-z0-9_]*\}(?=[<>])", s[self.i:])
            if m and not self.dbracket:
                self.i += m.end()
                continue
            w = self.word()
            if w.text == "":
                self.i += 1                      # (a lone metacharacter the rules above missed)
                continue
            self.toks.append(w)
            if w.lit == "case":
                self.case += 1
            elif w.lit == "esac" and self.case:
                self.case -= 1
            elif w.lit == "[[":
                self.dbracket = True
            elif w.lit == "]]":
                self.dbracket = False
            elif w.lit == "=~" and self.dbracket:
                self.regex_next = True
        if self.heredocs:
            self.heredoc_bodies()


def scan_expansions(text, sink, line):
    """$( ) and ` ` inside text that is otherwise data (an unquoted here-document)."""
    lx = Lexer(text, sink, 0, line)
    while lx.i < len(text):
        c = text[lx.i]
        if c == "\\":
            lx.i += 2
        elif c == "$":
            lx.dollar()
        elif c == "`":
            lx.i += 1
            lx.backtick()
        else:
            if c == "\n":
                lx.line += 1
            lx.i += 1


# ── programs that run another program: how many of their words to step over ─────────────
def skip_opts(args, with_value=(), flags_end_at_first_plain=True):
    """index of the first argument that is not an option (or an option's value)."""
    i = 0
    while i < len(args):
        a = args[i].lit
        if a is None:
            return i
        if a == "--":
            return i + 1
        if a.startswith("--"):
            if "=" not in a and a.split("=")[0] in with_value:
                i += 1
            i += 1
            continue
        if a.startswith("-") and len(a) > 1:
            if a in with_value:
                i += 1
            i += 1
            continue
        return i
    return i


def after_wrapper(name, args):
    """the index in ARGS where the program NAME runs begins, or None."""
    if name in ("nohup", "keep", "doas", "pkexec", "chrt"):
        return 0
    if name == "kawa-term":                       # kawa-term [--app ID TITLE] CMD…
        if args and args[0].lit == "--float":     # kawa-term --float [OPTION…] TITLE SIZE -- CMD…
            for i, a in enumerate(args):
                if a.lit == "--":
                    return i + 1
            return None
        return 3 if args and args[0].lit == "--app" else 0
    if name == "exec":
        return skip_opts(args, ("-a",))
    if name == "setsid":
        return skip_opts(args)
    if name == "nice":
        return skip_opts(args, ("-n", "--adjustment"))
    if name == "ionice":
        return skip_opts(args, ("-c", "-n", "-p", "--class", "--classdata"))
    if name == "stdbuf":
        return skip_opts(args, ("-i", "-o", "-e"))
    if name == "timeout":
        i = skip_opts(args, ("-s", "-k", "--signal", "--kill-after"))
        return i + 1                              # (the duration)
    if name == "env":
        i = skip_opts(args, ("-u", "-C", "--unset", "--chdir", "-S"))
        while i < len(args) and args[i].lit is not None and ASSIGN.match(args[i].lit):
            i += 1
        return i
    if name in ("sudo", "runuser"):
        return skip_opts(args, ("-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T",
                                "--user", "--group", "--chdir", "--host", "--prompt",
                                "--other-user", "--command-timeout", "-l", "-w", "--login"))
    if name == "xargs":
        return skip_opts(args, ("-n", "-I", "-P", "-d", "-L", "-s", "-a", "-E", "--max-args",
                                "--max-procs", "--delimiter", "--arg-file"))
    if name == "flock":
        i = skip_opts(args, ("-w", "-E", "--timeout", "--conflict-exit-code", "-c", "--command"))
        if i < len(args) and args[i].lit is not None and args[i].lit.isdigit():
            return None                           # flock FD: no program
        return i + 1                              # flock FILE PROGRAM…
    if name == "systemd-run":
        return skip_opts(args, ("-p", "--property", "-u", "--unit", "--description", "-E",
                                "--setenv", "--slice", "-M", "--machine", "-H", "--host",
                                "--uid", "--gid", "--nice", "--working-directory", "-D",
                                "--on-calendar", "--on-active", "--timer-property"))
    if name == "systemd-inhibit":
        return skip_opts(args, ("--what", "--who", "--why", "--mode"))
    if name in ("foot", "footclient"):
        return skip_opts(args, ("-c", "-o", "-f", "-t", "-T", "-a", "-D", "-w", "-W", "-p", "-d",
                                "-s", "--config", "--override", "--font", "--term", "--title",
                                "--app-id", "--working-directory", "--window-size-pixels",
                                "--window-size-chars", "--print-pid", "--log-level",
                                "--server-socket", "--toplevel-tag"))
    return None


class Parser:
    def __init__(self, toks, sink):
        self.t, self.sink, self.fallback = toks, sink, False

    def call(self, name, line):
        if name.startswith(("/usr/bin/", "/bin/", "/usr/sbin/", "/sbin/", "/usr/local/bin/", "/usr/local/sbin/", "/usr/libexec/")):
            name = name.rsplit("/", 1)[1]
        elif name.startswith("~/.local/bin/"):
            name = name.rsplit("/", 1)[1]
        self.sink.calls.append((line, name, self.fallback))

    def command(self, i):
        """the simple command at I (its name a literal): recorded with what it runs; returns
        the index after it."""
        t = self.t
        name, line = t[i].lit, t[i].line
        args, j = [], i + 1
        while j < len(t) and t[j].kind != "op":
            if t[j].kind == "redir":
                j += 2
                continue
            args.append(t[j]); j += 1
        # PROGRAM … || OTHER: the caller has a way on when PROGRAM fails or is absent
        self.fallback = j < len(t) and t[j].text == "||"
        self.wrapped(name, line, args, t[i])
        self.fallback = False
        return j

    def wrapped(self, name, line, args, tok):
        m = re.match(r'^"?\$\{?HOME\}?/\.local/bin/([\w.+-]+)"?$', tok.text)
        if name is None and m:
            name = m.group(1)
        if name is None:
            return
        if name in BUILTINS or name in KEYWORDS:
            pass
        elif name in self.sink.funcs:
            pass
        else:
            self.call(name, line)
        lits = [a.lit for a in args]
        # checks that make a program optional
        if name == "command" and lits[:1] in (["-v"], ["-V"]):
            self.sink.guards.update(x for x in lits[1:] if x)
            return
        if name == "type":
            self.sink.guards.update(x for x in lits if x and not x.startswith("-"))
            return
        if name == "hash":
            self.sink.guards.update(x for x in lits if x and not x.startswith("-"))
            return
        # a string that is itself shell
        if name in ("sh", "bash", "dash"):
            for k, a in enumerate(lits):
                if a == "-c" or (a and a.startswith("-") and not a.startswith("--") and "c" in a):
                    if k + 1 < len(args) and args[k + 1].lit is not None:
                        run_string(args[k + 1].lit, self.sink, args[k + 1].line)
                    break
            return
        if name == "alias":                       # alias ls='eza …': its value runs as shell
            for a in args:
                if a.lit and "=" in a.lit:
                    run_string(a.lit.split("=", 1)[1], self.sink, a.line)
            return
        if name == "trap":
            if args and args[0].lit is not None and args[0].lit not in ("-", "-p", "-l", ""):
                run_string(args[0].lit, self.sink, args[0].line)
            return
        if name == "swayidle":
            k = 0
            while k < len(args):
                a = args[k].lit
                if a in ("timeout", "idlehint"):
                    k += 2 if a == "timeout" else 1
                    if a == "timeout" and k < len(args) and args[k].lit is not None:
                        run_string(args[k].lit, self.sink, args[k].line)
                    k += 1
                elif a in ("resume", "before-sleep", "after-resume", "lock", "unlock"):
                    if k + 1 < len(args) and args[k + 1].lit is not None:
                        run_string(args[k + 1].lit, self.sink, args[k + 1].line)
                    k += 2
                else:
                    k += 1
            return
        if name == "find":
            for k, a in enumerate(lits):
                if a in ("-exec", "-execdir", "-ok", "-okdir") and k + 1 < len(args):
                    self.wrapped(args[k + 1].lit, args[k + 1].line, args[k + 2:], args[k + 1])
            return
        if name == "command" and lits[:1] != ["-p"]:
            k = 0
        elif name == "command":
            k = 1
        elif name in ("builtin", "time"):
            k = 0
        else:
            k = after_wrapper(name, args)
        if k is None or k >= len(args):
            return
        nxt = args[k]
        if nxt.lit is None and not re.match(r'^"?\$\{?HOME\}?/\.local/bin/', nxt.text):
            return
        if nxt.lit is not None and ASSIGN.match(nxt.lit) and name != "env":
            return
        self.wrapped(nxt.lit, nxt.line, args[k + 1:], nxt)

    def run(self):
        t, n = self.t, len(self.t)
        i, expect, mode, cases = 0, True, None, 0
        while i < n:
            tok = t[i]
            if tok.kind == "redir":
                i += 2
                continue
            if mode == "pattern":
                if tok.kind == "op" and tok.text == ")":
                    mode, expect = None, True
                elif tok.kind == "w" and tok.lit == "esac":
                    cases = max(0, cases - 1)
                    mode, expect = None, False
                i += 1
                continue
            if mode == "case-word":
                if tok.kind == "w" and tok.lit == "in":
                    mode = "pattern"
                i += 1
                continue
            if mode == "dbracket":
                if tok.kind == "w" and tok.lit == "]]":
                    mode, expect = None, False
                i += 1
                continue
            if tok.kind == "op":
                if tok.text in (";;", ";&", ";;&"):
                    mode = "pattern" if cases else None
                    expect = False
                elif tok.text == ")":
                    expect = False
                else:
                    expect = True
                i += 1
                continue
            if not expect:
                i += 1
                continue
            w = tok.lit
            if ASSIGN.match(tok.text):           # A=1 B=$(…) PROGRAM: the program is still to come
                i += 1
                continue
            if w is None:                        # "$cmd", $(…): a name only known when it runs
                if re.match(r'^"?\$\{?HOME\}?/\.local/bin/', tok.text):
                    i = self.command(i)
                else:
                    i += 1
                expect = False
                continue
            if w in KEYWORDS:
                if w == "case":
                    cases += 1
                    mode, expect = "case-word", False
                elif w == "esac":
                    cases = max(0, cases - 1)
                    expect = False
                elif w == "[[":
                    mode = "dbracket"
                elif w in ("for", "select"):
                    expect = False
                elif w == "function":
                    if i + 1 < n and t[i + 1].lit:
                        self.sink.funcs.add(t[i + 1].lit)
                    i += 2
                    while i < n and t[i].kind == "op" and t[i].text in "()":
                        i += 1
                    expect = True
                    continue
                elif w in ("fi", "done", "}", "in", "]]"):
                    expect = False
                elif w == "coproc" and i + 2 < n and t[i + 1].lit and t[i + 2].lit in ("{", "(", "while", "until", "if", "for", "case"):
                    i += 2                       # coproc NAME { … }: NAME names the coprocess, it runs nothing
                    expect = True
                    continue
                else:                            # then do else elif if while until ! { time coproc
                    expect = True
                i += 1
                continue
            if (i + 2 < n and t[i + 1].kind == "op" and t[i + 1].text == "("
                    and t[i + 2].kind == "op" and t[i + 2].text == ")"):
                self.sink.funcs.add(w)
                i += 3
                expect = True
                continue
            i = self.command(i)
            expect = False


def funcs_of(text):
    """every function a piece of shell defines (a function may be used above its definition)."""
    names = set(re.findall(r"^\s*(?:function\s+)?([A-Za-z_][\w:.-]*)\s*\(\s*\)", text, re.M))
    names |= set(re.findall(r"^\s*function\s+([A-Za-z_][\w:.-]*)", text, re.M))
    return names


def run_string(text, sink, line=1):
    lx = Lexer(text, sink, 0, line)
    lx.run()
    Parser(lx.toks, sink).run()


def programs(text, line=1, funcs=()):
    """[(line, name, guarded)] for a piece of shell."""
    sink = Sink()
    sink.funcs = set(funcs) | funcs_of(text)
    run_string(text, sink, line)
    # python inside the script: subprocess.run(["prog", …]) and shutil.which("prog")
    for m in re.finditer(r"subprocess\.\w+\(\s*\[\s*[\"']([\w.+-]+)[\"']", text):
        sink.calls.append((text.count("\n", 0, m.start()) + line, m.group(1), False))
    sink.guards |= set(re.findall(r"shutil\.which\(\s*[\"']([\w.+-]+)[\"']", text))
    return [(ln, n, fb or n in sink.guards) for ln, n, fb in sink.calls]


def main(argv):
    if argv[:1] == ["-c"]:
        items = [("-c", argv[1])]
    else:
        items = [(f, open(f, encoding="utf-8").read()) for f in argv]
    for where, text in items:
        for ln, name, guarded in programs(text):
            print(f"{ln}\t{name}" + ("\tguarded" if guarded else ""))


if __name__ == "__main__":
    main(sys.argv[1:])
