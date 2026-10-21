"""Textual's themes by name, and the Theme class kawa-torrra builds its own with (it keeps what
it was given). FAKE_TEXTUAL=8.0.1: the one that had no ansi-dark yet."""
import os


class Theme:
    def __init__(self, name, **kw):
        self.name, self.variables = name, {}
        self.__dict__.update(kw)


BUILTIN_THEMES = {n: Theme(n) for n in ("textual-dark", "textual-light", "nord", "gruvbox")}
if os.environ.get("FAKE_TEXTUAL") == "8.0.1":
    BUILTIN_THEMES["textual-ansi"] = Theme("textual-ansi")
else:
    BUILTIN_THEMES.update({"ansi-dark": Theme("ansi-dark", ansi=True, variables={"from-ansi-dark": "kept"}),
                           "ansi-light": Theme("ansi-light", ansi=True)})
