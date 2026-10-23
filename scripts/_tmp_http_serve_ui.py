from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os
os.chdir(r"d:\Git\Roblox\A4_Slap\assets\ui")
class H(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)
print("READY 8791", flush=True)
ThreadingHTTPServer(("127.0.0.1", 8791), H).serve_forever()