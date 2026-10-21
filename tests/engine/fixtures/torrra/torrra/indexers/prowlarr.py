"""torrra's Prowlarr indexer, as far as kawa-torrra relies on it: its health check before the
window opens (it would ask Prowlarr — here it says so in FAKE_LOG) and its search (each one
logged; one result)."""
import os


def _log(line):
    if os.environ.get("FAKE_LOG"):
        with open(os.environ["FAKE_LOG"], "a") as f:
            f.write(line + "\n")


class ProwlarrIndexer:
    name = "prowlarr"

    def __init__(self, url="http://127.0.0.1:9696", api_key=None):
        self.url, self.api_key = url, api_key

    async def healthcheck(self):
        _log("torrra's own health check")
        return False                                  # (Prowlarr still starting, as it would find it)

    async def search(self, query, use_cache=True):
        _log(f"torrra's search: {query}")
        return [f"a result for {query}"]
