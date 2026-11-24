from copy import deepcopy
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from threading import BoundedSemaphore, Event
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'guild-server'))

from guild_content import ACHIEVEMENTS, CARDS
from guild_engine import Engine
from guild_replay import ReplayRecorder, ReplayStore


def make_engine(*heroes, **options):
    players = [dict(id=i, name=str(i), hero=hero) for i, hero in enumerate(heroes)]
    engine = Engine(players, seed=18, options=dict(options, setup_draft=False, start_player=0))
    engine.state.update(phase='action', turn=0, pending=None, effects=[])
    return engine


class MatchRules(unittest.TestCase):
    def test_necromancer_army_scores_printed_strength_payment_icons(self):
        engine = make_engine('bai_white', solo=True)
        player = engine.state['players'][0]
        player.update(gold=200, strength=0, hand=[6, 20, 81, 5, 214])
        for card_id in (6, 20, 81, 5):
            engine._play(player, dict(type='play', card=card_id, strength=0))
            engine._drain_effects()

        army = engine.cards[20]
        self.assertEqual(army['point'], 0)
        self.assertEqual(engine._points(player, army), 6)
        engine._flip(engine._source(player, player['played'].index(81)))
        self.assertEqual(engine._points(player, army), 4)
        engine._finish()
        self.assertEqual(engine.state['phase'], 'finished')
        self.assertEqual(engine.score_breakdown(0)['cards'], 6)

    def test_creating_and_restoring_mode_prints_keeps_other_matches_isolated(self):
        card = next(key for key, data in CARDS.items()
                    if data.get('printed_code') == 'D-002' and not data.get('archived_print'))
        original_print = deepcopy(CARDS[card])
        multiplayer = make_engine('bai_white', 'alicia_white')
        player = multiplayer.state['players'][0]
        player['played'] = [card] * 21
        solo = make_engine('bai_white', solo=True)
        self.assertEqual(multiplayer._points(player, multiplayer.cards[card]), 7)
        self.assertEqual(solo._points(player, solo.cards[card]), 6)
        restored = Engine.restore(multiplayer.export())
        self.assertEqual(restored._points(player, restored.cards[card]), 7)
        self.assertEqual(solo._points(player, solo.cards[card]), 6)
        self.assertEqual(CARDS[card], original_print)

    def test_development_preview_quotes_the_same_festival_spend_as_execution(self):
        engine = make_engine('bai_white', 'alicia_white', forest=True)
        player = engine.state['players'][0]
        player.update(gold=15, strength=0, festival_tokens=4)
        preview = engine.view(0)['players'][0]['action_previews']['development']
        self.assertNotIn('action_previews', engine.view(None)['players'][0])
        self.assertNotIn('action_previews', engine.view(1)['players'][0])
        self.assertNotIn('gold,strength', preview['standard'])
        self.assertNotIn('gold,strength', preview['festival'])
        quote = preview['festival']['strength,gold']
        self.assertEqual(quote['festival'], dict(strength=3, gold=1))
        engine.apply(0, dict(type='develop', slots=['strength', 'gold'], festival=quote['festival']))
        self.assertEqual(engine.state['players'][0]['developed'], ['strength', 'gold'])
        self.assertEqual(engine.state['players'][0]['festival_tokens'], 0)

    def test_achievement_preview_checks_gold_and_extra_cost_together(self):
        engine = make_engine('bai_white', 'alicia_white')
        player = engine.state['players'][0]
        player.update(gold=10, strength=1)
        card = dict(price=10, can_trans=True, costs={'gold': 5}, effect={})
        with patch.dict(ACHIEVEMENTS, {'test-cost': card}):
            engine.state['public_achievements'] = ['test-cost']
            preview = engine.view(0)['players'][0]['action_previews']['achievements']
            quotes = preview['public']['test-cost']
            self.assertIn('error', quotes[0])
            self.assertEqual(quotes[1], dict(gold=10, strength=1))
            action = dict(type='achievement', id='test-cost', public=True)
            with self.assertRaises(ValueError):
                engine.apply(0, action)
            engine.apply(0, dict(action, strength=1))
        self.assertIn('test-cost', engine.state['players'][0]['earned_achievements'])


class ReplayRecording(unittest.TestCase):
    def test_ordered_detached_snapshots_and_release_on_finish(self):
        engine = make_engine('bai_white', 'alicia_white')
        player = engine.state['players'][0]
        player['hand'] = [5]
        with TemporaryDirectory() as folder:
            store = ReplayStore(folder)
            recorder = ReplayRecorder(store)
            try:
                ident = recorder.start('test match', engine)
                player['hand'] = [7]
                recorder.append(ident, engine, 'second')
                player['hand'] = [9]
            finally:
                recorder.close()

            self.assertEqual(store.public_read(ident)['count'], 0)
            self.assertFalse(store.summaries()[0]['preview']['finished'])
            with self.assertRaises(FileNotFoundError):
                store.public_read(ident, 0)

            recorder = ReplayRecorder(store)
            try:
                engine._finish()
                recorder.append(ident, engine, 'finished')
            finally:
                recorder.close()

            self.assertEqual(store.public_read(ident)['count'], 3)
            steps = [store.public_read(ident, index) for index in range(3)]
            self.assertEqual([step['game']['players'][0]['hand'] for step in steps], [[5], [7], [9]])
            self.assertEqual(store.summaries()[0]['status'], '已结束')

    def test_disk_failure_in_one_replay_does_not_stop_other_recordings(self):
        engine = make_engine('bai_white', 'alicia_white')
        with TemporaryDirectory() as folder:
            store = ReplayStore(folder)
            write = store.append

            def fail_one_step(ident, snapshot, label, player, recorded_at):
                if label == 'disk failure':
                    raise OSError('test disk error')
                write(ident, snapshot, label, player, recorded_at)

            with patch.object(store, 'append', side_effect=fail_one_step), self.assertLogs(level='ERROR'):
                recorder = ReplayRecorder(store)
                try:
                    broken = recorder.start('broken', engine)
                    recorder.append(broken, engine, 'disk failure')
                    recorder.finish(broken)
                    intact = recorder.start('intact', engine)
                    recorder.finish(intact)
                finally:
                    recorder.close()

            self.assertEqual(store.public_read(broken)['status'], '已中断')
            self.assertEqual(store.public_read(intact, 0)['label'], '对局开始')

    def test_full_writer_queue_does_not_publish_an_active_match(self):
        engine = make_engine('bai_white', 'alicia_white')
        with TemporaryDirectory() as folder:
            store = ReplayStore(folder)
            start = store.start
            allow_disk_write = Event()

            def slow_start(*args):
                if not allow_disk_write.wait(timeout=5):
                    raise OSError('timed out waiting for test')
                start(*args)

            with patch.object(store, 'start', side_effect=slow_start), self.assertLogs(level='ERROR'):
                recorder = ReplayRecorder(store)
                recorder.slots = BoundedSemaphore(1)
                try:
                    ident = recorder.start('still active', engine)
                    recorder.append(ident, engine, 'queue filled')
                finally:
                    allow_disk_write.set()
                    recorder.close()

            self.assertEqual(store.public_read(ident)['status'], '进行中')
            with self.assertRaises(FileNotFoundError):
                store.public_read(ident, 0)
