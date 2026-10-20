"""Textual's themes by name. FAKE_TEXTUAL=8.0.1: the one that had no ansi-dark yet."""
import os

BUILTIN_THEMES = {n: object() for n in ("textual-dark", "textual-light", "nord", "gruvbox")}
if os.environ.get("FAKE_TEXTUAL") == "8.0.1":
    BUILTIN_THEMES["textual-ansi"] = object()
else:
    BUILTIN_THEMES.update({"ansi-dark": object(), "ansi-light": object()})
