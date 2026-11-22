import json
import queue
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


HOST = "127.0.0.1"
PORT = 8000
WEB_DIR = Path(__file__).resolve().parent.parent / "webmesh"

CUBE_VERTICES = (
    # Front
    -1, -1,  1,   0,  0,  1,   0, 0,
     1, -1,  1,   0,  0,  1,   1, 0,
     1,  1,  1,   0,  0,  1,   1, 1,
    -1, -1,  1,   0,  0,  1,   0, 0,
     1,  1,  1,   0,  0,  1,   1, 1,
    -1,  1,  1,   0,  0,  1,   0, 1,

    # Back
     1, -1, -1,   0,  0, -1,   0, 0,
    -1, -1, -1,   0,  0, -1,   1, 0,
    -1,  1, -1,   0,  0, -1,   1, 1,
     1, -1, -1,   0,  0, -1,   0, 0,
    -1,  1, -1,   0,  0, -1,   1, 1,
     1,  1, -1,   0,  0, -1,   0, 1,

    # Left
    -1, -1, -1,  -1,  0,  0,   0, 0,
    -1, -1,  1,  -1,  0,  0,   1, 0,
    -1,  1,  1,  -1,  0,  0,   1, 1,
    -1, -1, -1,  -1,  0,  0,   0, 0,
    -1,  1,  1,  -1,  0,  0,   1, 1,
    -1,  1, -1,  -1,  0,  0,   0, 1,

    # Right
     1, -1,  1,   1,  0,  0,   0, 0,
     1, -1, -1,   1,  0,  0,   1, 0,
     1,  1, -1,   1,  0,  0,   1, 1,
     1, -1,  1,   1,  0,  0,   0, 0,
     1,  1, -1,   1,  0,  0,   1, 1,
     1,  1,  1,   1,  0,  0,   0, 1,

    # Top
    -1,  1,  1,   0,  1,  0,   0, 0,
     1,  1,  1,   0,  1,  0,   1, 0,
     1,  1, -1,   0,  1,  0,   1, 1,
    -1,  1,  1,   0,  1,  0,   0, 0,
     1,  1, -1,   0,  1,  0,   1, 1,
    -1,  1, -1,   0,  1,  0,   0, 1,

    # Bottom
    -1, -1, -1,   0, -1,  0,   0, 0,
     1, -1, -1,   0, -1,  0,   1, 0,
     1, -1,  1,   0, -1,  0,   1, 1,
    -1, -1, -1,   0, -1,  0,   0, 0,
     1, -1,  1,   0, -1,  0,   1, 1,
    -1, -1,  1,   0, -1,  0,   0, 1,
)

_running = False
_version = 0
_vertices = CUBE_VERTICES
_clients = []
_server = None
_server_thread = None
_lock = threading.Lock()


def get_vertices():
    with _lock:
        return _vertices


def get_version():
    with _lock:
        return _version


def get_snapshot():
    with _lock:
        return {
            "type": "vertices",
            "version": _version,
            "data": _vertices,
        }


def get_state():
    snapshot = get_snapshot()
    return {
        "running": _running,
        "version": snapshot["version"],
        "vertices": snapshot["data"],
    }


def is_running():
    return _running


def think():
    time.sleep(0.01)


def set_vertices(vertices):
    global _vertices, _version

    if not _running:
        raise RuntimeError("Scene server is not running")

    values = tuple(float(value) for value in vertices)

    if len(values) % 8 != 0:
        raise ValueError("Each vertex must contain 8 values: XYZ, normal XYZ, UV")

    if len(values) % 24 != 0:
        raise ValueError("Vertices must form complete triangles")

    with _lock:
        _vertices = values
        _version += 1
        snapshot = {
            "type": "vertices",
            "version": _version,
            "data": _vertices,
        }
        clients = list(_clients)

    for client in clients:
        client.put(snapshot)

    print(f"Mesh updated: version={_version}, vertices={len(_vertices) // 8}, clients={len(clients)}")
    return _version


def add_vertices(vertices):
    values = tuple(float(value) for value in vertices)
    return set_vertices(get_vertices() + values)


def subscribe():
    client = queue.Queue()

    with _lock:
        _clients.append(client)
        client.put({
            "type": "vertices",
            "version": _version,
            "data": _vertices,
        })
        client_count = len(_clients)

    print(f"Web client connected; clients={client_count}")
    return client


def unsubscribe(client):
    with _lock:
        if client in _clients:
            _clients.remove(client)
        client_count = len(_clients)

    print(f"Web client disconnected; clients={client_count}")


class SceneHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        path = urlsplit(self.path).path

        if path == "/api/vertices":
            self.send_json(get_snapshot())
            return

        if path == "/events":
            self.send_events()
            return

        self.send_static(path)

    def send_json(self, data):
        content = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    def send_static(self, path):
        files = {
            "/": "index.html",
            "/index.html": "index.html",
            "/app.js": "app.js",
            "/style.css": "style.css",
        }
        content_types = {
            "index.html": "text/html; charset=utf-8",
            "app.js": "application/javascript; charset=utf-8",
            "style.css": "text/css; charset=utf-8",
        }

        if path not in files:
            self.send_error(404)
            return

        filename = files[path]
        content = (WEB_DIR / filename).read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_types[filename])
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    def send_events(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        client = subscribe()

        try:
            while _running:
                try:
                    snapshot = client.get(timeout=10)
                    content = json.dumps(snapshot).encode("utf-8")
                    self.wfile.write(b"data: " + content + b"\n\n")
                except queue.Empty:
                    self.wfile.write(b": keep-alive\n\n")

                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            unsubscribe(client)
            self.close_connection = True


def start(host=HOST, port=PORT):
    global _running, _server, _server_thread

    if _running:
        return

    server = ThreadingHTTPServer((host, port), SceneHandler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)

    _server = server
    _server_thread = thread
    _running = True
    thread.start()
    print(f"Scene server started: http://{host}:{port}")


def stop():
    global _running, _server, _server_thread

    if not _running:
        return

    _running = False
    server = _server
    thread = _server_thread

    if server is not None:
        server.shutdown()
        server.server_close()

    if thread is not None:
        thread.join(timeout=2)

    _server = None
    _server_thread = None
    print("Scene server stopped")


def parse_vertex(line):
    values = tuple(float(value) for value in line.replace(",", " ").split())

    if len(values) != 8:
        raise ValueError("Need exactly 8 numbers: x y z nx ny nz u v")

    return values


def console_loop():
    pending = []

    print("Enter one vertex: x y z nx ny nz u v")
    print("Every 3 vertices add one triangle. Enter q to quit.")

    while _running:
        try:
            line = input(f"Vertex {len(pending) + 1}/3> ")
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if line.strip().lower() in ("q", "quit", "exit"):
            break

        if not line.strip():
            continue

        try:
            vertex = parse_vertex(line)
        except ValueError as error:
            print(f"Error: {error}")
            continue

        pending.append(vertex)

        if len(pending) == 3:
            triangle = tuple(value for vertex in pending for value in vertex)
            set_vertices(get_vertices() + triangle)
            pending.clear()
            print("Triangle added and sent to clients")
        else:
            print(f"Saved. Need {3 - len(pending)} more vertex(es)")


def main():
    try:
        start()
        console_loop()
    finally:
        stop()


if __name__ == "__main__":
    main()
