"""秘药行动的统一状态与执行校验。"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "guild-server"))

from guild_content import POTIONS
from guild_engine import Engine
from guild_potions import available, potion_state, use_error


def action_engine():
    engine = Engine([{"id": 0, "name": "测试", "hero": "bai_white"}], seed=7)
    engine.state.update(phase="action", turn=0)
    player = engine.state["players"][0]
    player["pot"] = 10
    return engine, player


class PotionRuleTests(unittest.TestCase):
    def test_state_is_the_same_source_as_execution(self):
        engine, player = action_engine()
        self.assertEqual(potion_state(engine, player, "gold"), "可用")
        self.assertEqual(potion_state(engine, player, "build"), "无可据点化营地")

        before_gold = player["gold"]
        engine.apply(0, {"type": "potion", "option": "gold"})
        player = engine.state["players"][0]
        self.assertEqual(player["gold"], before_gold + POTIONS["gold"]["effect"]["gold"])
        self.assertEqual(player["pot"], 9)
        self.assertEqual(potion_state(engine, player, "gold"), "本轮已用")
        self.assertEqual(potion_state(engine, player, "strength"), "可用")

    def test_free_card_without_a_playable_card_is_rejected(self):
        engine, player = action_engine()
        player["hand"] = []
        self.assertEqual(potion_state(engine, player, "free_card"), "无可用事件卡")
        self.assertFalse(available(engine, player, "free_card"))
        self.assertIn("没有可以免费打出", use_error(engine, player, {"type": "potion", "option": "free_card"}))
        before_pot = player["pot"]
        with self.assertRaises(ValueError):
            engine.apply(0, {"type": "potion", "option": "free_card"})
        player = engine.state["players"][0]
        self.assertEqual(player["pot"], before_pot)
        self.assertNotIn("free_card", engine.state["potions_used"])

    def test_alchemy_potions_use_the_same_target_gate(self):
        engine, player = action_engine()
        engine.state["potions_disabled"] = []
        player["pot"] = 10
        player["hand"] = []
        self.assertEqual(potion_state(engine, player, "alchemy_card"), "无可用事件卡")
        self.assertEqual(potion_state(engine, player, "alchemy_build"), "无可据点化营地")

    def test_view_exposes_own_potion_states_only(self):
        engine, player = action_engine()
        own = engine.view(0)["players"][0]
        self.assertEqual(own["potion_states"]["gold"], "可用")
        spectator = engine.view(None)["players"][0]
        self.assertNotIn("potion_states", spectator)


if __name__ == "__main__":
    unittest.main()
