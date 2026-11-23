"""开局流程：房间选人物 → 轮抽 → 情报收集 → 选该人物的白/黑面。

选面前只按两版中较低的开局资源起步；选面后补足差额并发放
该面的初始抽牌、标签、私有牌堆与角色专属开场效果。
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "guild-server"))

from guild_content import CHARACTERS, HEROES, starting_resources
from guild_engine import Engine
from guild_modes import normalize_options

RESOURCE_KEYS = ("gold", "strength", "pot", "gold_pro", "str_pro", "pot_pro")


def first_hero(character):
    return next(hero for hero in CHARACTERS[character]["variants"].values()
                if HEROES[hero].get("available", False))


def min_allocation(character):
    values = [starting_resources(hero) for hero in CHARACTERS[character]["variants"].values()
              if HEROES[hero].get("available", False)]
    return {key: min(int(value.get(key, 0)) for value in values) for key in RESOURCE_KEYS}


def make_engine(characters, setup_draft=True):
    options = normalize_options({"setup_draft": setup_draft}, len(characters))
    specs = [{"id": index, "name": "P%d" % index, "hero": first_hero(character),
              "hero_character": character} for index, character in enumerate(characters)]
    return Engine(specs, seed=7, options=options)


def run_draft(engine, players):
    for step in range(1, 8):
        for pid in players:
            engine.apply(pid, {"type": "draft_pick", "draft_step": step, "index": 0})


class FacePhaseTests(unittest.TestCase):
    def test_face_comes_after_research_and_restores_resources(self):
        characters = ["bai", "hainie"]
        engine = make_engine(characters)
        self.assertEqual(engine.state["phase"], "draft")
        for player in engine.state["players"]:
            self.assertFalse(player["face_chosen"])
            self.assertEqual(player["hand"], [])
            expected = min_allocation(player["hero_character"])
            for key in RESOURCE_KEYS:
                self.assertEqual(player[key], expected[key])

        run_draft(engine, [0, 1])
        self.assertEqual(engine.state["phase"], "research")

        # 选面之前不能做行动；情报收集照常扣费。
        with self.assertRaises(ValueError):
            engine.apply(0, {"type": "choose_face", "variant": "white"})
        offered = engine.state["players"][0]["offered"]
        engine.apply(0, {"type": "research", "cards": offered[:2]})
        engine.apply(1, {"type": "research", "cards": []})
        self.assertEqual(engine.state["phase"], "face")

        with self.assertRaises(ValueError):
            engine.apply(0, {"type": "pass"})
        with self.assertRaises(ValueError):
            engine.apply(0, {"type": "choose_face", "variant": "not-a-face"})

        engine.apply(0, {"type": "choose_face", "variant": "black"})
        self.assertEqual(engine.state["phase"], "face")
        engine.apply(1, {"type": "choose_face", "variant": "white"})
        self.assertEqual(engine.state["phase"], "action")
        self.assertFalse(engine.state["face_pending"])

        for pid in (0, 1):
            player = engine.state["players"][pid]
            hero = HEROES[player["hero"]]
            allocation = starting_resources(player["hero"])
            self.assertTrue(player["face_chosen"])
            self.assertEqual(len(player["hand"]), (2 if pid == 0 else 0) + hero.get("draw", 0))
            self.assertEqual(len(player["hero_deck"]), hero.get("private_deck", 0))
            expected_gold = allocation["gold"] - (6 if pid == 0 else 0)
            self.assertEqual(player["gold"], expected_gold)
            for key in RESOURCE_KEYS:
                if key != "gold":
                    self.assertEqual(player[key], allocation.get(key, 0))

    def test_characters_can_choose_face_without_a_setup_draft(self):
        engine = make_engine(["siren"], setup_draft=False)
        self.assertEqual(engine.state["phase"], "research")
        engine.apply(0, {"type": "research", "cards": []})
        self.assertEqual(engine.state["phase"], "face")
        engine.apply(0, {"type": "choose_face", "variant": "white"})
        self.assertEqual(engine.state["phase"], "action")
        self.assertTrue(engine.state["players"][0]["face_chosen"])

    def test_hidden_variant_until_face_is_chosen(self):
        engine = make_engine(["bai", "hainie"])
        run_draft(engine, [0, 1])
        engine.apply(0, {"type": "research", "cards": []})
        engine.apply(1, {"type": "research", "cards": []})
        view = engine.view(0)
        self.assertEqual(view["phase"], "face")
        self.assertTrue(view["players"][0]["face_chosen"] is False)
        self.assertEqual(view["players"][1]["variant"], "")
        engine.apply(0, {"type": "choose_face", "variant": "white"})
        self.assertEqual(engine.view(0)["players"][1]["variant"], "")


if __name__ == "__main__":
    unittest.main()
