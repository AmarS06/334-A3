from core.vocab import Reset, TimedOut


class FakeStream:
    def __init__(self, chunks=(), fail_after=None, failure=Reset, stall=False):
        self.chunks = [bytes(c) for c in chunks]
        self.fail_after = fail_after
        self.failure = failure
        self.stall = stall
        self.sent = bytearray()
        self.finished = False
        self.dropped = False
        self.local = ("10.10.1.10", 62000)
        self.remote = ("10.10.3.10", 8080)
        self.taken = 0

    def put(self, data, deadline=None):
        self.sent += data

    def take(self, limit, deadline=None):
        if self.fail_after is not None and self.taken >= self.fail_after:
            raise self.failure("scripted failure")
        if not self.chunks:
            if self.stall:
                raise TimedOut("scripted stall")
            return b""
        piece = self.chunks[0][:limit]
        rest = self.chunks[0][limit:]
        if rest:
            self.chunks[0] = rest
        else:
            self.chunks.pop(0)
        self.taken += 1
        return piece

    def finish(self):
        self.finished = True
        return True

    def drop(self):
        self.dropped = True
