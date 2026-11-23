import json
import queue
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from dataclasses import dataclass, field

HOST = "0.0.0.0"
PORT = 8000
WEB_DIR = Path(__file__).resolve().parent.parent / "webmesh"
CUBE_VERTICES = ()

@dataclass()
class Scene:
	is_init: bool = False
	running: bool = False
	version: int = 0
	vertices: tuple = CUBE_VERTICES
	server: ThreadingHTTPServer | None = None
	server_thread: threading.Thread | None = None

	clients: list = field(default_factory=list)
	lock: threading.Lock = field(default_factory=threading.Lock)

	def get_vertices(self):
		with self.lock:
			return self.vertices
	def get_version(self):
		with self.lock:
			return self.version
	def get_snapshot(self):
		with self.lock:
			return {
				"type": "vertices",
				"version": self.version,
				"data": self.vertices,
			}
	def get_state(self):
		snapshot = get_snapshot()
		return {
			"running": self.running,
			"version": snapshot["version"],
			"vertices": snapshot["data"],
		}

	def is_running(self):
		return self.running

	def think():
		time.sleep(0.01)

	def set_vertices(self, vertices):
		if not self.running:
			raise RuntimeError("Scene server is not running")

		values = tuple(float(value) for value in vertices)
		if(len(values) % 8 != 0):
			raise ValueError("Each vertex must contain 8 values: XYZ, normal, uv")
		if len(values) % 24 != 0:
			raise ValueError("Vertices must form complete triangles")

		with self.lock:
			self.vertices = values
			self.version += 1
			snapshot = {
				"type":		"vertices",
				"version":	self.version,
				"data":		self.vertices
			}
			clients = list(self.clients)

		for client in clients:
			client.put(snapshot)

		print(f"Mesh updated: version={_version}, vertices={len(_vertices) // 8}, clients={len(clients)}")
		return self.version

	def add_vertices(self, vertices):
		values = tuple(float(value) for value in vertices)
		return self.set_vertices(self.get_vertices()+values)


	def subscribe():
		client = queue.Queue()

		with self.lock():
			self.clients.append(client)
			client.put({
				"type": "vertices",
				"version": self.version,
				"data": self.vertices

			})
			client_count: int = len(self.clients)
		print(f"Web client connected; clients={client_count}")
		return client

	def unsubscribe(client):
		with self.lock:
			if client in self.clients:
				self.clients.remove(client)
			client_count = len(self.clients)
		print(f"Web client disconnected; clients={client_count}")

class SceneHandler(BaseHTTPRequestHandler):
	protocol_version = "HTTP/1.1"

	def do_GET(self):
		path urlsplit(self.path).path

		if 
