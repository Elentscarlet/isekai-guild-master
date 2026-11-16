from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'guild-server'))
from guild_content import CARDS
from guild_engine import Engine


def game(hero='bai_white', count=2):
    engine = Engine([dict(id=i, name='P%s' % i, hero=hero if i == 0 else 'bai_white')
                     for i in range(count)], seed=18,
                    options=dict(solo=count == 1, setup_draft=False, start_player=0))
    engine.state.update(phase='action', turn=0, pending=None, effects=[])
    return engine, engine._player(0)


class NecromancerArmy(unittest.TestCase):
    def test_each_printed_symbol_counts_including_self_and_duplicate_cards(self):
        engine, player = game()
        player.update(played=[20, 6, 6, 1], card_states=[])
        self.assertEqual(engine._points(player, CARDS[20]), 6)
        self.assertEqual(engine.score_breakdown(0)['cards'], 8)
        self.assertEqual(engine.view(0)['players'][0]['score_breakdown']['cards'], 8)
        engine._finish()
        result = next(row for row in engine.state['scores'] if row['id'] == 0)
        self.assertEqual(result['breakdown']['cards'], 8)

    def test_two_armies_each_award_their_own_points(self):
        engine, player = game()
        player.update(played=[20, 20, 6], card_states=[])
        self.assertEqual(engine.score_breakdown(0)['cards'], 13)

    def test_face_down_cards_stop_counting_and_face_down_army_stops_scoring(self):
        engine, player = game()
        player.update(played=[20, 6, 6, 1], card_states=[])
        states = engine._card_states(player)
        states[2]['face_down'] = True
        self.assertEqual(engine._points(player, CARDS[20]), 4)
        self.assertEqual(engine.score_breakdown(0)['cards'], 5)
        states[0]['face_down'] = True
        self.assertEqual(engine.score_breakdown(0)['cards'], 1)

    def test_skadi_substitution_does_not_add_a_printed_symbol(self):
        engine, player = game('skadi_white')
        player.update(played=[20, 1, 1], card_states=[], hand=[6, 6])
        engine._player(1).update(played=[20, 6, 6], card_states=[])
        self.assertTrue(engine._has_passive(player, 'strength_as_gold'))
        self.assertEqual(engine._points(player, CARDS[20]), 2)

    def test_gold_and_strength_payments_score_equally_and_potions_match_the_scan(self):
        for count in (1, 2, 5):
            for strength in (0, 6):
                with self.subTest(players=count, strength=strength):
                    engine, player = game(count=count)
                    player.update(gold=100, strength=6, hand=[20])
                    previous = [p['pot'] for p in engine.state['players']]
                    engine.apply(0, dict(type='play', card=20, strength=strength))
                    self.assertEqual(engine._points(engine._player(0), CARDS[20]), 2)
                    self.assertEqual(engine._player(0)['pot'], previous[0] + (2 if count == 1 else 3))
                    for i in range(1, count):
                        self.assertEqual(engine._player(i)['pot'], previous[i] + 1)


if __name__ == '__main__': unittest.main()
