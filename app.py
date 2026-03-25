from http.server import SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import TCPServer


class StaticHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        public_dir = Path(__file__).resolve().parent / "public"
        super().__init__(*args, directory=str(public_dir), **kwargs)


if __name__ == "__main__":
    port = 8000
    with TCPServer(("", port), StaticHandler) as httpd:
        print(f"Unseen Hunger Python server running on http://localhost:{port}")
        httpd.serve_forever()
