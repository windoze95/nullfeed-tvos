#!/usr/bin/env python3
"""Tiny HTTP server: GET /capture/<name> -> `xcrun simctl io <UDID> screenshot`.

The app under test calls this between navigation steps so the host captures
the true simulator framebuffer (video frames included) at native resolution.
Env: UDID (simulator), OUTDIR (where PNGs land), PORT (default 8765).
"""
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

UDID = os.environ["UDID"]
OUTDIR = os.environ["OUTDIR"]
PORT = int(os.environ.get("PORT", "8765"))

os.makedirs(OUTDIR, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not self.path.startswith("/capture/"):
            self.send_response(404)
            self.end_headers()
            return
        name = self.path.split("/capture/", 1)[1].split("?")[0]
        name = "".join(c for c in name if c.isalnum() or c in "-_") or "shot"
        out = os.path.join(OUTDIR, f"{name}.png")
        r = subprocess.run(
            ["xcrun", "simctl", "io", UDID, "screenshot", out],
            capture_output=True,
        )
        self.send_response(200 if r.returncode == 0 else 500)
        self.end_headers()
        self.wfile.write(r.stderr or b"ok")
        print(f"captured {out}", flush=True)

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
