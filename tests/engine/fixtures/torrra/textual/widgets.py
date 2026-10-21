"""Textual's Static, as a compose() yields it: its words, as given."""


class Static:
    def __init__(self, renderable="", *, markup=True, id=None, classes=""):
        self.renderable, self.markup, self.id, self.classes = renderable, markup, id, classes
