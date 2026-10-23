import http.server
import socketserver
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "patched"
PORT = 27865


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        print(f"serving {ROOT} on {PORT}", flush=True)
        httpd.serve_forever()
