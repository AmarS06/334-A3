import random
import unittest

from packets.checksum import internet_checksum, verifies
from packets.egress import compose
from packets.ingress import Anything, Exact, Listening, screen
from packets.ipv4 import HeaderTemplate, IdSource
from packets.logline import render
from packets.records import ACK, FIN, PSH, SYN, DropReason, Flow, SegmentIntent, packed
from packets.seqspace import unwrap, wrap
from packets.tcpwire import scan_mss


def rfc1071(data):
    if len(data) % 2:
        data += b"\x00"
    total = sum(int.from_bytes(data[i : i + 2], "big") for i in range(0, len(data), 2))
    while total >> 16:
        total = (total & 0xFFFF) + (total >> 16)
    return (~total) & 0xFFFF


FLOW = Flow(packed("10.10.1.10"), 62000, packed("10.10.3.10"), 8080)
CLIENT_VIEW = Exact(packed("10.10.1.10"), 62000, packed("10.10.3.10"), 8080)
SERVER_VIEW = Exact(packed("10.10.3.10"), 8080, packed("10.10.1.10"), 62000)


def build(intent, ident=7):
    return compose(intent, FLOW, HeaderTemplate(FLOW.local_ip, FLOW.remote_ip, 64), IdSource(ident), 65535)


class Checksum(unittest.TestCase):
    def test_matches_rfc1071(self):
        rng = random.Random(1)
        for _ in range(3000):
            data = bytes(rng.getrandbits(8) for _ in range(rng.randint(1, 80)))
            ours, theirs = internet_checksum(data), rfc1071(data)
            self.assertTrue(ours == theirs or {ours, theirs} == {0, 0xFFFF})

    def test_verifies_own_checksum(self):
        header = bytearray(build(SegmentIntent(1, None, SYN, True, b""))[:20])
        self.assertTrue(verifies(bytes(header)))
        header[3] ^= 1
        self.assertFalse(verifies(bytes(header)))


class Sequence(unittest.TestCase):
    def test_wrap_unwrap(self):
        for reference in (0, 1 << 31, (1 << 32) - 1, (1 << 32) + 5, 10**12):
            for delta in (-(1 << 31) + 1, -1, 0, 1, (1 << 31) - 1):
                self.assertEqual(unwrap(wrap(reference + delta), reference), reference + delta)


class Identity(unittest.TestCase):
    def test_lfsr_period_and_nonzero(self):
        ids = IdSource(12345)
        seen = {ids.next() for _ in range(65535)}
        self.assertEqual(len(seen), 65535)
        self.assertNotIn(0, seen)


class Codec(unittest.TestCase):
    def test_round_trip(self):
        for intent in (
            SegmentIntent(1000, None, SYN, True, b""),
            SegmentIntent((1 << 32) + 7, 99, ACK | PSH, False, b"odd"),
            SegmentIntent(5, 6, ACK | FIN, False, b""),
        ):
            record = screen(build(intent), Anything())
            self.assertEqual(record.seq, wrap(intent.seq))
            self.assertEqual(record.ack, 0 if intent.ack is None else wrap(intent.ack))
            self.assertEqual(record.flags, intent.flags if intent.ack is not None else intent.flags & ~ACK)
            self.assertEqual(record.payload, intent.payload)
            self.assertEqual(record.mss, 1460 if intent.carries_mss else None)
            self.assertNotEqual(record.ip_id, 0)
            self.assertEqual(record.window, 65535)

    def test_log_line(self):
        record = screen(build(SegmentIntent(1000, None, SYN, True, b"")), Anything())
        self.assertRegex(
            render("SEND", record),
            r"^SEND 10\.10\.1\.10:62000 > 10\.10\.3\.10:8080 ttl=64 id=\d+ seq=1000 ack=0 "
            r"flags=0x02 win=65535 len=0 mss=1460$",
        )


class Gates(unittest.TestCase):
    def setUp(self):
        self.packet = build(SegmentIntent(1, 2, ACK | PSH, False, b"hello"))

    def mutate(self, index, value):
        data = bytearray(self.packet)
        data[index] = value
        return bytes(data)

    def test_drop_reasons(self):
        p = self.packet
        cases = {
            DropReason.SHORT: p[:10],
            DropReason.NOT_IPV4: self.mutate(0, 0x65),
            DropReason.BAD_IHL: self.mutate(0, 0x44),
            DropReason.BAD_LENGTH: p[:-1],
            DropReason.BAD_IP_CSUM: self.mutate(10, p[10] ^ 0xFF),
            DropReason.BAD_TCP_CSUM: self.mutate(len(p) - 1, p[-1] ^ 1),
            DropReason.FRAGMENT: self.mutate(6, p[6] | 0x20),
        }
        for reason, data in cases.items():
            with self.subTest(reason=reason):
                self.assertIs(screen(data, Anything()), reason)

    def test_filters(self):
        self.assertIs(screen(self.packet, Listening(9)), DropReason.FOREIGN)
        self.assertNotIsInstance(screen(self.packet, Listening(8080)), DropReason)
        self.assertIs(screen(self.packet, CLIENT_VIEW), DropReason.FOREIGN)
        self.assertNotIsInstance(screen(self.packet, SERVER_VIEW), DropReason)

    def test_option_scan(self):
        self.assertEqual(scan_mss(bytes([1, 1, 2, 4, 5, 0xB4, 4, 2, 8, 10] + [0] * 10)), (True, 1460))
        self.assertEqual(scan_mss(bytes([3, 3, 7, 1, 0, 0])), (True, None))
        self.assertEqual(scan_mss(bytes([2, 3, 5])), (False, None))
        self.assertEqual(scan_mss(bytes([8, 0])), (False, None))
        self.assertEqual(scan_mss(bytes([8, 12, 0])), (False, None))


if __name__ == "__main__":
    unittest.main()
