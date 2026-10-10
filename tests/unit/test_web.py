import io
import os
import tempfile
import unittest

from core.vocab import Reset
from fakes import FakeStream
from settings import Settings
from web.content import ERROR_PAGES, head, kind_of
from web.fetch import build_request, converse
from web.parsing import (
    BodyPiece, Done, Incomplete, Malformed, Oversize, RequestHeadReader, ResponseReader, StatusLine,
)
from web.serve import judge, respond
from web.urlparts import UrlError, split_url

GOOD_URLS = [
    ("http://10.10.3.10", ("10.10.3.10", 80, "/", "10.10.3.10")),
    ("http://10.10.3.10/", ("10.10.3.10", 80, "/", "10.10.3.10")),
    ("http://10.10.3.10:8080/a/b.html", ("10.10.3.10", 8080, "/a/b.html", "10.10.3.10:8080")),
    ("HTTP://Host.Example:80/x?y=1&z", ("Host.Example", 80, "/x?y=1&z", "Host.Example:80")),
    ("http://h/x#frag", ("h", 80, "/x", "h")),
    ("http://h:65535", ("h", 65535, "/", "h:65535")),
    ("http://h/?q", ("h", 80, "/?q", "h")),
    ("http://h/a%20b", ("h", 80, "/a%20b", "h")),
    ("http://h:1/", ("h", 1, "/", "h:1")),
    ("http://server/", ("server", 80, "/", "server")),
]
BAD_URLS = [
    "", "https://h/", "ftp://h/", "h/x", "http://", "http:///x", "http://h:/", "http://h:0/",
    "http://h:65536/", "http://h:123456/", "http://h:8x/", "http://u@h/", "http://[::1]/", "http://h?x",
    "http://h#x", "http://h/a b", "http://h/\x01", "http://h:-1/", "http://:80/", "http://h:8080:9/",
]


class Urls(unittest.TestCase):
    def test_good(self):
        for url, (host, port, path, authority) in GOOD_URLS:
            with self.subTest(url=url):
                self.assertEqual(tuple(split_url(url)), (host, port, path, authority))

    def test_bad(self):
        for url in BAD_URLS:
            with self.subTest(url=url):
                with self.assertRaises(UrlError):
                    split_url(url)

    def test_request_bytes(self):
        self.assertEqual(build_request(split_url("http://10.10.3.10:8080/a?b")),
                         b"GET /a?b HTTP/1.1\r\nHost: 10.10.3.10:8080\r\nConnection: close\r\n\r\n")


def collect(raw, step=None, eof=True):
    reader = ResponseReader()
    events = []
    if step is None:
        events += reader.feed(raw)
    else:
        for i in range(0, len(raw), step):
            events += reader.feed(raw[i:i + step])
    if eof:
        events += reader.at_eof()
    body = b"".join(e.data for e in events if isinstance(e, BodyPiece))
    return events, body


BODY = bytes(range(256)) * 20


def chunk(body, ext=b""):
    out = b""
    for i in range(0, len(body), 333):
        piece = body[i:i + 333]
        out += b"%x%s\r\n%s\r\n" % (len(piece), ext, piece)
    return out + b"0\r\n"


class Responses(unittest.TestCase):
    def check(self, raw, expected=BODY, code=200):
        for step in (None, 1, 7):
            events, body = collect(raw, step)
            self.assertEqual(body, expected)
            self.assertEqual([e for e in events if isinstance(e, StatusLine)][0].code, code)
            self.assertEqual(sum(isinstance(e, Done) for e in events), 1)

    def test_length(self):
        self.check(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n" % len(BODY) + BODY)

    def test_chunked_with_extensions_and_trailers(self):
        self.check(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip, chunked\r\n\r\n" + chunk(BODY, b";a=b")
                   + b"X-T: 1\r\n\r\n")

    def test_chunked_beats_length(self):
        head_part = b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nTransfer-Encoding: chunked\r\n\r\n"
        self.check(head_part + chunk(BODY) + b"\r\n")

    def test_close_delimited(self):
        self.check(b"HTTP/1.0 200 OK\r\nServer: x\r\n\r\n" + BODY)

    def test_bare_lf_and_case(self):
        self.check(b"HTTP/1.1 200 OK\ncontent-LENGTH: %d\n\n" % len(BODY) + BODY)

    def test_no_body_codes(self):
        self.check(b"HTTP/1.1 204 No Content\r\nContent-Length: 10\r\n\r\n", b"", 204)
        self.check(b"HTTP/1.1 304 Not Modified\r\n\r\n", b"", 304)

    def test_interim_skipped(self):
        interim = b"HTTP/1.1 100 Continue\r\n\r\n"
        self.check(interim + b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n" % len(BODY) + BODY)

    def test_empty_reason(self):
        self.check(b"HTTP/1.1 404 \r\nContent-Length: 0\r\n\r\n", b"", 404)
        self.check(b"HTTP/1.1 404\r\nContent-Length: 0\r\n\r\n", b"", 404)

    def test_truncations(self):
        raw = b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + chunk(BODY) + b"\r\n"
        for cut in (5, 30, 60, len(raw) - 3, len(raw) - 1):
            with self.subTest(cut=cut):
                with self.assertRaises(Incomplete):
                    collect(raw[:cut])
        with self.assertRaises(Incomplete):
            collect(b"HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabc")

    def test_malformed(self):
        for raw in (b"HTTX/1.1 200 OK\r\n\r\n", b"HTTP/1.1 2000 OK\r\n\r\n",
                    b"HTTP/1.1 200 OK\r\nContent-Length: 1, 2\r\n\r\n",
                    b"HTTP/1.1 200 OK\r\nContent-Length: -1\r\n\r\n",
                    b"HTTP/1.1 200 OK\r\nbad header\r\n\r\n",
                    b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nxyz\r\n"):
            with self.subTest(raw=raw):
                with self.assertRaises(Malformed):
                    collect(raw)


class ClientFlow(unittest.TestCase):
    def test_converse_writes_body_and_returns_code(self):
        raw = b"HTTP/1.1 404 Not Found\r\nContent-Length: 4\r\n\r\nnope"
        stream = FakeStream([raw[:10], raw[10:]])
        sink = io.BytesIO()
        self.assertEqual(converse(stream, sink, Settings(), b"REQ"), 404)
        self.assertEqual(sink.getvalue(), b"nope")
        self.assertEqual(bytes(stream.sent), b"REQ")

    def test_reset_propagates(self):
        stream = FakeStream([b"HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nab"], fail_after=1)
        with self.assertRaises(Reset):
            converse(stream, io.BytesIO(), Settings(), b"REQ")


class Server(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.root, "sub"))
        os.makedirs(os.path.join(self.root, "empty"))
        for name, data in (("index.html", b"<h1>i</h1>"), ("sub/index.html", b"s"), ("a.TXT", b"t"),
                           ("noext", b"n"), (".html", b"d")):
            with open(os.path.join(self.root, name), "wb") as handle:
                handle.write(data)

    def test_rule_order(self):
        cases = {
            "GET / HTTP/1.1": 200, "GET /sub HTTP/1.1": 200, "GET /sub/ HTTP/1.1": 200,
            "HEAD /a.TXT?x=../ HTTP/1.0": 200, "GET /index.html?a=1 HTTP/1.1": 200,
            "GET x HTTP/1.1": 400, "GET  / HTTP/1.1": 400, "GET / HTTP/1.1 ": 400, "GET / HTTP/11": 400,
            "GET / http/1.1": 400, "G(T / HTTP/1.1": 400, "": 400, "GET /": 400,
            "POST / HTTP/1.1": 501, "get / HTTP/1.1": 501, "FOO /../x HTTP/1.1": 501,
            "GET /../x HTTP/1.1": 403, "GET /sub/.. HTTP/1.1": 403, "GET /a/../b HTTP/1.1": 403,
            "GET /missing HTTP/1.1": 404, "GET /empty/ HTTP/1.1": 404, "GET /a%2etxt HTTP/1.1": 404,
            "GET /..x HTTP/1.1": 404,
        }
        for line, code in cases.items():
            with self.subTest(line=line):
                self.assertEqual(judge(line, self.root)[0], code)

    def test_types(self):
        expect = {
            "a.html": "text/html", "a.HTM": "text/html", "a.txt": "text/plain", "a.css": "text/css",
            "a.js": "application/javascript", "a.json": "application/json", "a.png": "image/png",
            "a.JPG": "image/jpeg", "a.jpeg": "image/jpeg", "a.gif": "image/gif", "a.pdf": "application/pdf",
            "a.bin": "application/octet-stream", "noext": "application/octet-stream",
            ".html": "application/octet-stream", "/x/y.tar.gz": "application/octet-stream",
        }
        for name, ctype in expect.items():
            with self.subTest(name=name):
                self.assertEqual(kind_of(name), ctype)

    def response(self, raw):
        stream = FakeStream([raw])
        respond(stream, Settings(), self.root)
        return bytes(stream.sent)

    def test_get_and_head_headers_match(self):
        get = self.response(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n")
        head_only = self.response(b"HEAD / HTTP/1.1\r\nHost: x\r\n\r\n")
        self.assertTrue(get.startswith(head_only))
        self.assertEqual(get[len(head_only):], b"<h1>i</h1>")
        self.assertIn(b"Content-Length: 10\r\n", head_only)
        self.assertIn(b"Connection: close\r\n", head_only)

    def test_error_bodies(self):
        reply = self.response(b"GET /nope HTTP/1.1\r\n\r\n")
        self.assertTrue(reply.startswith(b"HTTP/1.1 404 Not Found\r\n"))
        self.assertIn(b"Content-Type: text/html\r\n", reply)
        self.assertTrue(reply.endswith(ERROR_PAGES[404]))
        self.assertIn(b"Content-Length: %d\r\n" % len(ERROR_PAGES[404]), reply)

    def test_no_response_without_head(self):
        stream = FakeStream([b"GET / HTTP/1.1\r\n"], stall=True)
        respond(stream, Settings(), self.root)
        self.assertEqual(bytes(stream.sent), b"")
        stream = FakeStream([b"GET / HTTP/1.1\r\n"])
        respond(stream, Settings(), self.root)
        self.assertEqual(bytes(stream.sent), b"")

    def test_oversize_head(self):
        reader = RequestHeadReader(100)
        with self.assertRaises(Oversize):
            reader.feed(b"GET / HTTP/1.1\r\n" + b"X: y\r\n" * 50)

    def test_head_format(self):
        expected = (b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n"
                    b"Connection: close\r\n\r\n")
        self.assertEqual(head(200, 5, "text/plain"), expected)


if __name__ == "__main__":
    unittest.main()
