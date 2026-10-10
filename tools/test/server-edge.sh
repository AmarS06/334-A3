#!/usr/bin/env bash
# usage: bash server-edge.sh [HOST=10.10.3.10] [PORT=8080]
H=${1:-10.10.3.10}; P=${2:-8080}
raw(){ printf "$1" | nc -q 3 -w 15 "$H" "$P" 2>/dev/null | head -1 | tr -d '\r'; }
chk(){ got=$(raw "$2"); case "$got" in *" $1 "*) echo "PASS $1  <- $3";; *) echo "FAIL want $1 got '$got'  <- $3";; esac; sleep 0.5; }
chk 200 'GET / HTTP/1.1\r\nHost: x\r\n\r\n'                    'root -> index.html'
chk 200 'GET /sub/ HTTP/1.1\r\nHost: x\r\n\r\n'                'dir with trailing slash'
chk 200 'GET /sub HTTP/1.1\r\nHost: x\r\n\r\n'                 'dir without slash'
chk 200 'GET /index.html?q=1&a=b HTTP/1.1\r\nHost: x\r\n\r\n'  'query string ignored'
chk 200 'HEAD /index.html HTTP/1.1\r\nHost: x\r\n\r\n'         'HEAD'
chk 400 'GET index.html HTTP/1.1\r\n\r\n'                      'target not starting with /'
chk 400 'GET /  HTTP/1.1\r\n\r\n'                              'double space'
chk 400 'GET / HTTX/1.1\r\n\r\n'                               'bad version'
chk 400 'garbage\r\n\r\n'                                      'garbage line'
chk 501 'POST / HTTP/1.1\r\n\r\n'                              'POST'
chk 501 'DELETE /x HTTP/1.1\r\n\r\n'                           'DELETE'
chk 403 'GET /../etc/passwd HTTP/1.1\r\n\r\n'                  '.. segment'
chk 403 'GET /sub/../index.html HTTP/1.1\r\n\r\n'              '.. in middle'
chk 501 'FOO /../x HTTP/1.1\r\n\r\n'                           'rule order: 501 checked before 403'
chk 404 'GET /nope.txt HTTP/1.1\r\n\r\n'                       'missing file'
chk 404 'GET /emptydir/ HTTP/1.1\r\n\r\n'                      'dir without index.html'
echo "--- headers / content types"
for f in index.html a.txt s.css a.js d.json i.png p.JPG g.gif doc.pdf blob.bin noext; do
  printf '%-12s ' "$f"; curl -sI "http://$H:$P/$f" | tr -d '\r' | grep -iE '^(content-type|content-length|connection):' | tr '\n' ' '; echo
done
echo "--- 10 s head timeout (expect connection closed with NO response after ~10 s)"
python3 - "$H" "$P" <<'PY'
import socket, sys, time
s = socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=30)
start = time.time()
s.sendall(b"GET / HTTP/1.1\r\n")
got = b""
while True:
    piece = s.recv(4096)
    if not piece:
        break
    got += piece
elapsed = time.time() - start
verdict = "PASS" if not got and 9.0 <= elapsed <= 12.0 else "FAIL"
print(f"{verdict} head timeout: closed after {elapsed:.1f} s with {len(got)} response bytes")
PY
echo "--- server still alive?"; curl -s -o /dev/null -w '%{http_code}\n' "http://$H:$P/"
