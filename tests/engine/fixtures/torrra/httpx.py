"""httpx, as kawa-torrra uses it: one GET to Prowlarr. FAKE_PROWLARR says how Prowlarr answers
(ok · down · slow · 401 · 500 · noindexers); FAKE_LOG records the request."""
import json
import os


class HTTPError(Exception):
    pass


class TimeoutException(HTTPError):
    pass


class _Response:
    def __init__(self, code, body):
        self.status_code, self._body = code, body

    def json(self):
        return json.loads(self._body)


def get(url, headers=None, timeout=None):
    log = os.environ.get("FAKE_LOG")
    if log:
        with open(log, "a") as f:
            f.write(f"httpx.get {url} key={(headers or {}).get('X-Api-Key')} timeout={timeout}\n")
    mode = os.environ.get("FAKE_PROWLARR", "ok")
    if mode == "down":
        raise HTTPError("[Errno 111] Connection refused")
    if mode == "slow":
        raise TimeoutException("timed out")
    if mode in ("401", "500"):
        return _Response(int(mode), "{}")
    if mode == "noindexers":
        return _Response(200, json.dumps([{"enable": False}]))
    return _Response(200, json.dumps([{"enable": False}, {"enable": True}]))
