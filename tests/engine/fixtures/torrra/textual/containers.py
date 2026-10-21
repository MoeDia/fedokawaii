"""Textual's containers, as a compose() sees them: with-blocks whose children are the widgets
yielded inside them (here: each records its own id and classes)."""


class _Box:
    def __init__(self, *children, id=None, classes=""):
        self.id, self.classes = id, classes

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class Container(_Box):
    pass


class Grid(_Box):
    pass
