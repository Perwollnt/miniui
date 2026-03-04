#!/usr/bin/env python3
"""
Simple static server for httpdemo templates.

Usage:
  python server.py
  python server.py --port 8080
"""

from __future__ import annotations
import argparse
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        # Disable caching so template edits show up immediately.
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def guess_type(self, path: str) -> str:
        if path.endswith(".ui") or path.endswith(".lua"):
            return "text/plain; charset=utf-8"
        return super().guess_type(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    root = os.path.dirname(os.path.abspath(__file__))
    os.chdir(root)

    server = ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    print(f"httpdemo server running at http://localhost:{args.port}/")
    print(f"Serving: {root}")
    print("Use in CC:")
    print(f"  demo_http http://<YOUR_PC_IP>:{args.port}/page.ui")
    print("Press Ctrl+C to stop.")
    server.serve_forever()


if __name__ == "__main__":
    main()
