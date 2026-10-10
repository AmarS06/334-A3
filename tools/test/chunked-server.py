#!/usr/bin/env python3
# usage: python3 chunked-server.py [PORT=8001]   (serves /chunked /trailers /close /length /bad /truncated /204)
import socket
import sys

BODY = bytes(range(256)) * 600


def chunked(body, extensions=False, trailers=False):
    out = b""
    step = 7001
    for i in range(0, len(body), step):
        piece = body[i:i + step]
        ext = b";name=value" if extensions else b""
        out += b"%x" % len(piece) + ext + b"\r\n" + piece + b"\r\n"
    out += b"0\r\n"
    if trailers:
        out += b"X-Checksum: none\r\nX-More: 1\r\n"
    return out + b"\r\n"


def reply(path):
    if path == "/chunked":
        return b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + chunked(BODY), True
    if path == "/trailers":
        return b"HTTP/1.1 200 OK\r\ntransfer-encoding: Chunked\r\n\r\n" + chunked(BODY, True, True), True
    if path == "/close":
        return b"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n\r\n" + BODY, True
    if path == "/length":
        return b"HTTP/1.1 200 OK\r\nCONTENT-LENGTH: %d\r\n\r\n" % len(BODY) + BODY, True
    if path == "/truncated":
        return b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n" % (len(BODY) + 100) + BODY, True
    if path == "/bad":
        return b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n", True
    if path == "/204":
        return b"HTTP/1.1 204 No Content\r\n\r\n", True
    return b"HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nnot found", True


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("0.0.0.0", port))
    listener.listen(5)
    print(f"chunked test server on :{port}; expected body md5 is that of bytes(range(256))*600", flush=True)
    while True:
        conn, _ = listener.accept()
        with conn:
            head = b""
            while b"\r\n\r\n" not in head:
                data = conn.recv(4096)
                if not data:
                    break
                head += data
            line = head.split(b"\r\n", 1)[0].decode("latin-1")
            parts = line.split(" ")
            path = parts[1] if len(parts) > 1 else "/"
            payload, close = reply(path)
            conn.sendall(payload)
            print(f"{line} -> {len(payload)} bytes", flush=True)


if __name__ == "__main__":
    main()
