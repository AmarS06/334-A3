import unittest
from itertools import pairwise

from harness.sim import Sim
from logcheck import problems
from core.vocab import HandshakeTimeout, Refused, Reset, Stalled
from packets.records import RST, SegmentIntent
from settings import Settings

MEG = bytes(range(256)) * 4096


def lossy(loss, reorder=0.0, duplicate=0.0, mangle=0.0):
    return dict(loss=loss, reorder=reorder, duplicate=duplicate, mangle=mangle)


class Transfers(unittest.TestCase):
    def check(self, sim, clean=True):
        self.assertEqual(bytes(sim.client.inbox), sim.response)
        self.assertEqual(bytes(sim.server.inbox), sim.request)
        self.assertIsNone(sim.client.failure)
        self.assertIsNone(sim.server.failure)
        if clean:
            self.assertTrue(sim.client.finished)
            self.assertTrue(sim.server.finished)
        self.assertEqual(problems(sim.client.log), [])
        self.assertEqual(problems(sim.server.log), [])

    def test_clean_megabyte(self):
        self.check(Sim(seed=1, response=MEG).run())

    def test_loss_and_reorder_grid(self):
        for loss in (0.01, 0.05, 0.10):
            for reorder in (0.0, 0.25):
                for seed in (1, 2):
                    with self.subTest(loss=loss, reorder=reorder, seed=seed):
                        link = lossy(loss, reorder)
                        sim = Sim(seed=seed, response=MEG, forward=link, backward=dict(link))
                        self.check(sim.run(limit=600), clean=False)

    def test_duplicates_and_corruption(self):
        link = lossy(0.02, 0.1, 0.1, 0.05)
        sim = Sim(seed=4, response=MEG, forward=link, backward=dict(link))
        self.check(sim.run(limit=600), clean=False)
        self.assertTrue(sim.client.drops or sim.server.drops)

    def test_sequence_wrap(self):
        sim = Sim(seed=5, response=MEG, client_isn=(1 << 32) - 3000, server_isn=(1 << 32) - 400000,
                  backward=lossy(0.02, 0.2))
        self.check(sim.run(limit=600), clean=False)

    def test_bottleneck(self):
        sim = Sim(seed=6, response=MEG, backward=dict(rate=20e6, queue_bytes=30000, delay=0.005))
        self.check(sim.run())

    def test_client_closes_first(self):
        sim = Sim(seed=7, response=MEG, server_closes_first=False)
        self.check(sim.run())


class Handshake(unittest.TestCase):
    def test_each_handshake_segment_lost(self):
        for kind in ("forward", "backward"):
            for count in (1, 2, 3):
                with self.subTest(kind=kind, count=count):
                    sim = Sim(seed=8, **{kind: dict(drop_first=count)}).run()
                    self.assertEqual(bytes(sim.client.inbox), sim.response)

    def test_final_ack_lost_then_data(self):
        sim = Sim(seed=9, forward=dict(drop_first=2)).run()
        self.assertEqual(bytes(sim.client.inbox), sim.response)

    def test_give_up_timing(self):
        sim = Sim(seed=10, forward=dict(blackouts=[(0, 1e9)])).run(limit=30)
        self.assertIs(sim.client.failure, HandshakeTimeout)
        times = [t for t, rec in sim.client.sent_at if rec.flags & 0x02]
        gaps = [b - a for a, b in pairwise(times)]
        self.assertTrue(all(g <= 1.0 + 1e-9 for g in gaps), gaps)
        self.assertGreaterEqual(sim.now, 6.0)

    def test_server_give_up_resets_listener(self):
        sim = Sim(seed=11, backward=dict(blackouts=[(0, 1e9)])).run(limit=30)
        self.assertIs(sim.server.failure, HandshakeTimeout)

    def test_refused(self):
        sim = Sim(seed=12, refuse=True).run(limit=30)
        self.assertIs(sim.client.failure, Refused)
        self.assertLess(sim.now, 1.0)


class Failures(unittest.TestCase):
    def test_reset_mid_transfer(self):
        def strike(sim):
            node = sim.server
            seq = node.endpoint.outbound.snd_nxt
            sim.emit(node, SegmentIntent(seq, None, RST, False, b""))
        sim = Sim(seed=13, response=MEG, hooks=[(0.05, strike)]).run(limit=30)
        self.assertIs(sim.client.failure, Reset)

    def test_stray_reset_ignored(self):
        def stray(sim):
            node = sim.server
            seq = node.endpoint.outbound.snd_nxt + 5000
            sim.emit(node, SegmentIntent(seq, None, RST, False, b""))
        sim = Sim(seed=14, response=MEG, hooks=[(0.05, stray)]).run(limit=30)
        self.assertIsNone(sim.client.failure)
        self.assertEqual(bytes(sim.client.inbox), sim.response)

    def test_stall_after_peer_vanishes(self):
        sim = Sim(seed=15, response=MEG, forward=dict(blackouts=[(0.05, 1e9)])).run(limit=60)
        self.assertIs(sim.server.failure, Stalled)
        self.assertLess(sim.now, 0.05 + 10.0 + 2.0)

    def test_close_limit_when_fin_never_acked(self):
        probe = Sim(seed=16, response=b"y" * 3000).run()
        fin_time = min(t for t, r in probe.server.sent_at if r.flags & 0x01)

        def cut(sim):
            sim.forward.blackouts = [(sim.now, 1e9)]
        sim = Sim(seed=16, response=b"y" * 3000, hooks=[(fin_time + 1e-6, cut)]).run(limit=60)
        self.assertIs(sim.server.finished, False)
        self.assertLessEqual(sim.now - fin_time, 2.05)
        fins = [t for t, r in sim.server.sent_at if r.flags & 0x01]
        self.assertGreater(len(fins), 1)


class SettingsHooks(unittest.TestCase):
    def test_small_peer_mss_respected(self):
        sim = Sim(seed=17, settings=Settings(local_mss=536)).run()
        self.assertEqual(bytes(sim.client.inbox), sim.response)
        sizes = [len(r.payload) for _, r in sim.server.sent_at]
        self.assertLessEqual(max(sizes), 536)


if __name__ == "__main__":
    unittest.main()
