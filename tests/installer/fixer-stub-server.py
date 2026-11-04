#!/usr/bin/python3 -I
# tests/installer/fixer-stub-server.py — a stand-in for llama-server, for test_fixer and
# test_update_fixer: answers/N in its folder are its answers in turn ("@hang": nothing, "@die": the
# connection cut, "@slow": one word, then nothing), requests/N what it was asked; argv, env and
# netdev say how it was started. Its folder: $FK_STUB, or where it lies.
import http.server
import json
import os
import socketserver
import sys
import time

args = sys.argv[1:]
sock = args[args.index("--host") + 1]
base = os.environ.get("FK_STUB") or os.path.dirname(os.path.abspath(__file__))
os.makedirs(f"{base}/requests", exist_ok=True)
with open(f"{base}/argv", "w") as f:
    json.dump(args, f)
with open(f"{base}/env", "w") as f:
    json.dump(dict(os.environ), f)
with open(f"{base}/netdev", "w") as f, open("/proc/self/net/dev") as dev:
    f.write(dev.read())
n = [0]


def event(d):
    return b"data: " + json.dumps(d).encode() + b"\n\n"


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *a):
        pass

    def address_string(self):
        return "stub"

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        n[0] += 1
        with open(f"{base}/requests/{n[0]}.json", "wb") as f:
            f.write(body)
        try:
            with open(f"{base}/answers/{n[0]}") as f:
                ans = f.read()
        except OSError:
            ans = '{"verdict":"cannot_fix","reason":"no more answers","edits":[]}'
        if ans.startswith("@die"):
            self.connection.close()
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        if ans.startswith("@hang"):
            time.sleep(60)
            return
        if ans.startswith("@slow"):
            self.wfile.write(event({"choices": [{"delta": {"content": "{"}}]}))
            self.wfile.flush()
            time.sleep(60)
            return
        self.wfile.write(event({"choices": [{"delta": {"reasoning_content": "thinking"}}]}))
        self.wfile.write(event({"choices": [{"delta": {"content": ans}}],
                                "timings": {"prompt_n": 9, "predicted_n": 9, "predicted_per_second": 33.3}}))
        self.wfile.write(b"data: [DONE]\n\n")


class S(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

    def get_request(self):
        c, _ = super().get_request()
        return c, ("stub", 0)


if __name__ == "__main__":
    S(sock, H).serve_forever()
