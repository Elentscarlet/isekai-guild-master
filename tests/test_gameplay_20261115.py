from copy import deepcopy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'guild-server'))
from guild_engine import Engine
from guild_content import CARDS, ACHIEVEMENTS


def game(hero='skadi_white'):
    engine = Engine([dict(id=0, name='A', hero=hero), dict(id=1, name='B', hero='bai_white')],
                    options=dict(setup_draft=False, start_player=0), seed=18)
    engine.state.update(phase='action', turn=0, pending=None, effects=[])
    return engine, engine._player(0)


class GameplayRegression(unittest.TestCase):
    def test_cursed_fox_seal_can_be_played_with_nine_gold(self):
        engine, player = game('bai_white')
        player.update(gold=9, strength=0, hand=[99], tiles=['tile21'])
        production = player['gold_pro']
        engine.apply(0, dict(type='play', card=99))
        player = engine._player(0)
        self.assertEqual(player['gold'], 0)
        self.assertIn(99, player['played'])
        self.assertEqual(player['gold_pro'], production + 4)

    def test_cursed_fox_seal_rejects_eight_gold_without_spending(self):
        engine, player = game('bai_white')
        player.update(gold=8, strength=0, hand=[99], tiles=['tile21'])
        before = deepcopy(engine.state)
        with self.assertRaises(ValueError): engine.apply(0, dict(type='play', card=99))
        self.assertEqual(engine.state, before)

    def test_skadi_can_keep_gold_when_paying_normal_card(self):
        engine, player = game()
        player.update(gold=40, strength=5, hand=[5])
        with patch.dict(CARDS, {5: dict(id=5, name='测试', price=12, available=True)}):
            engine.apply(0, dict(type='play', card=5, strength=3))
        player = engine._player(0)
        self.assertEqual((player['gold'], player['strength']), (40, 2))

    def test_skadi_can_mix_coins_and_strength(self):
        engine, player = game()
        player.update(gold=40, strength=5, hand=[5])
        with patch.dict(CARDS, {5: dict(id=5, name='测试', price=12, available=True)}):
            engine.apply(0, dict(type='play', card=5, strength=2))
        player = engine._player(0)
        self.assertEqual((player['gold'], player['strength']), (38, 3))

    def test_skadi_research_and_development_keep_coins(self):
        for kind in ('research', 'develop'):
            with self.subTest(kind=kind):
                engine, player = game()
                player.update(gold=40, strength=5, offered=[5], researched=False)
                engine.apply(0, dict(type='payment_preference', strength=4))
                if kind == 'research':
                    engine.state.update(phase='research', round=2)
                    engine.apply(0, dict(type='research', cards=[5]))
                else:
                    engine.apply(0, dict(type='develop', slots=['gold'], count=1))
                self.assertEqual(engine._player(0)['gold'], 40)
                self.assertEqual(engine._player(0)['strength'], 4 if kind == 'research' else 1)

    def test_skadi_can_pay_non_transferable_royal_with_strength(self):
        engine, player = game()
        key = next(iter(ACHIEVEMENTS))
        player.update(gold=40, strength=5, achievements=[key])
        with patch.dict(ACHIEVEMENTS, {key: dict(name='测试王权', price=12, point=2)}):
            engine.apply(0, dict(type='achievement', id=key, strength=3))
        player = engine._player(0)
        self.assertEqual((player['gold'], player['strength']), (40, 2))
        self.assertIn(key, player['earned_achievements'])

    def test_other_heroes_still_need_the_transfer_symbol(self):
        engine, player = game('bai_white')
        player.update(gold=40, strength=5, hand=[5])
        before = deepcopy(engine.state)
        with patch.dict(CARDS, {5: dict(id=5, name='测试', price=12, available=True)}):
            with self.assertRaises(ValueError): engine.apply(0, dict(type='play', card=5, strength=3))
        self.assertEqual(engine.state, before)

    def test_phrase_counts_current_points_and_ignores_face_down_cards(self):
        engine, player = game()
        player.update(played=[334, 2, 117, 3, 193], card_states=[])
        states = engine._card_states(player)
        states[3]['face_down'] = True
        states[4]['counters'] = 3
        self.assertEqual(engine._stat(player, 'best_event_point'), 3)
        self.assertEqual(engine.score_breakdown(0)['cards'], 4)
        states[4]['counters'] = 7
        self.assertEqual(engine._points(player, CARDS[334]), 7)
        states[4]['face_down'] = True
        self.assertEqual(engine._points(player, CARDS[334]), 2)
        engine._finish()
        self.assertEqual(next(row for row in engine.state['scores'] if row['id'] == 0)['breakdown']['cards'], engine.score_breakdown(0)['cards'])

    def test_upgrade_at_two_and_five_affection_reaches_snapshots(self):
        engine, player = game('bai_white')
        player.update(gold=100, strength=10, pot=10, affection=1, developed=['cards'])
        engine._develop(player, 1, dict(slots=['gold']), free=True)
        self.assertEqual(engine.view(0)['players'][0]['hero_level'], 2)
        engine._develop(player, 3, dict(slots=['strength', 'pot', 'territory']), free=True)
        self.assertEqual(engine.view(0)['players'][0]['hero_level'], 3)


if __name__ == '__main__': unittest.main()
