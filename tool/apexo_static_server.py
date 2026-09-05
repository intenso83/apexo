"""Serve Apexo's optimized web build with the headers required by WASM.

This intentionally disables browser caching for local development so a newly
built beta cannot be hidden behind an older Flutter service-worker response.
"""

from __future__ import annotations

import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class ApexoRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=61110)
    parser.add_argument("--directory", default="build/web")
    args = parser.parse_args()

    def handler(*handler_args, **handler_kwargs):
        return ApexoRequestHandler(
            *handler_args,
            directory=args.directory,
            **handler_kwargs,
        )

    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving Apexo at http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
