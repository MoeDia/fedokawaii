"""torrra's first screen: its compose() (kawa-torrra puts its own in its place), its search
line, its version."""
from textual.widgets import Static

__version__ = "2.5.1"


class SearchInput(Static):
    def __init__(self, placeholder="", id=None):
        super().__init__("", id=id)
        self.placeholder = placeholder


class WelcomeScreen:
    def __init__(self, indexer=None):
        self.indexer = indexer

    def compose(self):
        yield Static("TORRRA 🏴‍☠️ banner", id="banner")
