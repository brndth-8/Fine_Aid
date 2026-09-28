"""Serve build/web locally the same way firebase.json hosting does.

  flutter build web -t lib/main_web.dart --dart-define-from-file=config/web.json
  python tool/serve_web.py            # http://localhost:5960

Real files are served as-is, "/" and the admin path get index.html, and every
other path gets 404.html with an HTTP 404 status.
"""
import http.server
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.join(REPO, 'build', 'web')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5960
with open(os.path.join(REPO, 'config', 'web.json')) as f:
    SLUG = json.load(f)['ADMIN_PATH']


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/' or os.path.isfile(os.path.join(ROOT, path.lstrip('/'))):
            return super().do_GET()
        if path == f'/{SLUG}' or path.startswith(f'/{SLUG}/'):
            self.path = '/index.html'
            return super().do_GET()
        with open(os.path.join(ROOT, '404.html'), 'rb') as f:
            body = f.read()
        self.send_response(404)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    print(f'Serving {ROOT} on http://localhost:{PORT} (admin: /{SLUG})')
    http.server.ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
