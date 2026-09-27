"""Serve this offline app on localhost. Run: python serve.py"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import webbrowser

os.chdir(Path(__file__).resolve().parent)
server = ThreadingHTTPServer(("127.0.0.1", 8765), SimpleHTTPRequestHandler)
print("Rahnama: http://127.0.0.1:8765")
webbrowser.open("http://127.0.0.1:8765")
server.serve_forever()
