import heapq
import random

from core.endpoint import Endpoint
from core.listener import Listener
from core.vocab import Deliver, Emit, Failed, Finished, Note, Opened, PeerDone
from packets.egress import compose
from packets.ingress import Anything, Exact, Listening, screen
from packets.ipv4 import HeaderTemplate, IdSource
from packets.logline import render
from packets.records import ACK, RST, DropReason, Flow, SegmentIntent, packed
from settings import Settings


class Channel:
    def __init__(self, rng, loss=0.0, reorder=0.0, duplicate=0.0, delay=0.01, rate=None, queue_bytes=None,
                 blackouts=(), drop_first=0, mangle=0.0):
        self.rng = rng
        self.loss = loss
        self.reorder = reorder
        self.duplicate = duplicate
        self.delay = delay
        self.rate = rate
        self.queue_bytes = queue_bytes
        self.blackouts = blackouts
        self.drop_first = drop_first
        self.mangle = mangle
        self.busy_until = 0.0
        self.sent = 0
        self.dropped = 0

    def transit(self, now, packet):
        self.sent += 1
        if self.sent <= self.drop_first or any(a <= now < b for a, b in self.blackouts):
            self.dropped += 1
            return []
        if self.rate is not None:
            backlog = max(0.0, self.busy_until - now) * self.rate / 8
            if self.queue_bytes is not None and backlog + len(packet) > self.queue_bytes:
                self.dropped += 1
                return []
            self.busy_until = max(now, self.busy_until) + len(packet) * 8 / self.rate
            leave = self.busy_until
        else:
            leave = now
        if self.rng.random() < self.loss:
            self.dropped += 1
            return []
        copies = 2 if self.rng.random() < self.duplicate else 1
        arrivals = []
        for _ in range(copies):
            extra = self.rng.uniform(0.005, 0.05) if self.rng.random() < self.reorder else 0.0
            data = packet
            if self.rng.random() < self.mangle:
                spot = self.rng.randrange(len(packet))
                data = packet[:spot] + bytes([packet[spot] ^ 0x40]) + packet[spot + 1:]
            arrivals.append((leave + self.delay + extra, data))
        return arrivals


class Node:
    def __init__(self, name, ip, port, settings, rng):
        self.name = name
        self.ip = packed(ip)
        self.port = port
        self.settings = settings
        self.ids = IdSource(rng.randrange(1, 65536))
        self.endpoint = None
        self.flow = None
        self.template = None
        self.wanted = None
        self.listener = None
        self.inbox = bytearray()
        self.eof = False
        self.opened = False
        self.finished = None
        self.failure = None
        self.log = []
        self.sent_at = []
        self.drops = {}

    def bind(self, remote_ip, remote_port):
        self.flow = Flow(self.ip, self.port, remote_ip, remote_port)
        self.template = HeaderTemplate(self.ip, remote_ip, self.settings.ttl)
        self.wanted = Exact(self.ip, self.port, remote_ip, remote_port)


class Sim:
    def __init__(self, seed=1, settings=None, forward=None, backward=None, client_isn=None, server_isn=None,
                 request=b"GET / HTTP/1.1\r\n\r\n", response=b"x" * 100000, server_closes_first=True,
                 refuse=False, hooks=()):
        self.rng = random.Random(seed)
        self.settings = settings or Settings()
        self.forward = Channel(self.rng, **(forward or {}))
        self.backward = Channel(self.rng, **(backward or {}))
        self.client = Node("client", "10.10.1.10", 62000, self.settings, self.rng)
        self.server = Node("server", "10.10.3.10", 8080, self.settings, self.rng)
        self.server.listener = Listener(8080)
        self.server.wanted = Listening(8080)
        self.client_isn = self.rng.getrandbits(32) if client_isn is None else client_isn
        self.server_isn = self.rng.getrandbits(32) if server_isn is None else server_isn
        self.request = request
        self.response = response
        self.server_closes_first = server_closes_first
        self.refuse = refuse
        self.hooks = sorted(hooks, key=lambda h: h[0])
        self.now = 0.0
        self.events = []
        self.counter = 0
        self.answered = False
        self.client_closed = False
        self.server_closed = False

    def push(self, when, node, packet):
        self.counter += 1
        heapq.heappush(self.events, (when, self.counter, node, packet))

    def emit(self, node, intent):
        packet = compose(intent, node.flow, node.template, node.ids, self.settings.advertised_window)
        sent = screen(packet, Anything())
        node.log.append(render("SEND", sent))
        node.sent_at.append((self.now, sent))
        channel = self.forward if node is self.client else self.backward
        target = self.server if node is self.client else self.client
        for when, data in channel.transit(self.now, packet):
            self.push(when, target, data)

    def apply(self, node, actions):
        for action in actions:
            if isinstance(action, Emit):
                self.emit(node, action.intent)
            elif isinstance(action, Deliver):
                node.inbox += action.data
            elif isinstance(action, PeerDone):
                node.eof = True
            elif isinstance(action, Opened):
                node.opened = True
            elif isinstance(action, Finished):
                node.finished = action.clean
            elif isinstance(action, Failed):
                node.failure = action.kind
            elif isinstance(action, Note):
                pass

    def arrive(self, node, packet):
        record = screen(packet, node.wanted)
        if isinstance(record, DropReason):
            node.drops[record] = node.drops.get(record, 0) + 1
            return
        if node.endpoint is None and self.refuse and node is self.server:
            node.bind(packed(record.src_ip), record.src_port)
            self.emit(node, SegmentIntent(0, record.seq + 1, RST | ACK, False, b""))
            node.flow = None
            return
        if node.endpoint is None:
            if node.listener is None or not node.listener.admits(record):
                return
            node.bind(packed(record.src_ip), record.src_port)
            node.log.append(render("RECV", record))
            node.endpoint, actions = Endpoint.passive(self.settings, self.server_isn, record, self.now)
            self.apply(node, actions)
            return
        node.log.append(render("RECV", record))
        self.apply(node, node.endpoint.arrival(record, self.now))

    def start(self):
        self.client.bind(self.server.ip, self.server.port)
        self.client.endpoint, actions = Endpoint.active(self.settings, self.client_isn, self.now)
        self.apply(self.client, actions)

    def react(self):
        client, server = self.client, self.server
        if client.opened and not getattr(self, "asked", False):
            self.asked = True
            self.apply(client, client.endpoint.queue(self.request, self.now))
        if server.opened and not self.answered and len(server.inbox) >= len(self.request):
            self.answered = True
            self.apply(server, server.endpoint.queue(self.response, self.now))
            if self.server_closes_first:
                self.server_closed = True
                self.apply(server, server.endpoint.wind_down(self.now))
        if client.eof and not self.client_closed:
            self.client_closed = True
            self.apply(client, client.endpoint.wind_down(self.now))
        if not self.server_closes_first and server.eof and self.answered and not self.server_closed:
            self.server_closed = True
            self.apply(server, server.endpoint.wind_down(self.now))
        if (not self.server_closes_first and len(client.inbox) >= len(self.response)
                and not self.client_closed):
            self.client_closed = True
            self.apply(client, client.endpoint.wind_down(self.now))

    def settled(self, node):
        return node.finished is not None or node.failure is not None

    def run(self, limit=120.0):
        self.start()
        while self.now < limit:
            if self.settled(self.client) and (self.settled(self.server) or self.server.endpoint is None):
                break
            times = [e.endpoint.next_deadline() for e in (self.client, self.server) if e.endpoint is not None]
            times = [t for t in times if t is not None]
            if self.events:
                times.append(self.events[0][0])
            if self.hooks:
                times.append(self.hooks[0][0])
            if not times:
                break
            self.now = max(self.now, min(times))
            while self.hooks and self.hooks[0][0] <= self.now:
                self.hooks.pop(0)[1](self)
            while self.events and self.events[0][0] <= self.now:
                _, _, node, packet = heapq.heappop(self.events)
                self.arrive(node, packet)
                self.react()
            for node in (self.client, self.server):
                if node.endpoint is not None:
                    self.apply(node, node.endpoint.clock(self.now))
            self.react()
        return self
