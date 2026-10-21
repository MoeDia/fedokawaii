"""torrra's app, as far as a load test sees it: TorrraApp (whose CSS kawa-torrra sets) and the
screens importing Textual, Rich and httpx. FAKE_TEXTUAL_BROKEN names a file: while it exists,
Textual is broken (a version torrra was not written for), and importing this fails as the
real one would."""
import os

_flag = os.environ.get("FAKE_TEXTUAL_BROKEN")
if _flag and os.path.exists(_flag):
    raise ImportError("No module named 'textual.widgets._input'")


class TorrraApp:
    CSS = ""
