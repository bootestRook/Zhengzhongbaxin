import copy
import unittest

from tools import defense_pipeline as pipeline


class IceTermsDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def compile(self, source):
        return pipeline.compile_catalog(*self.inputs[:4], source)

    def test_exact_library_and_recruitment(self):
        source = copy.deepcopy(self.inputs[4])
        before = copy.deepcopy(source)
        c = self.compile(source)
        rows = {int(k): v for k, v in c["options"].items() if v["type"] == [13]}
        self.assertEqual(sorted(rows), list(range(200400, 200410)))
        self.assertEqual(c["heroes"]["13"]["initial_options"], [200400])
        self.assertEqual([rows[i]["term_id"] for i in sorted(rows)], list(range(400, 410)))
        self.assertEqual([rows[i]["draw_weight"] for i in sorted(rows)],
                         [5000, 3000, 3000, 2000, 2000, 2000, 1000, 1000, 1000, 2000])
        self.assertEqual(rows[200401]["options_num"], 2)
        self.assertEqual(rows[200409]["premise1"], [[200401, 1], [200402, 1], [200405, 1]])
        descriptions = [
            "向目标方向射出3根箭矢，每根造成50%冰系伤害",
            "多重射击伤害+60%",
            "多重射击伤害+20%，穿透+1",
            "多重射击伤害+20%，齐射+1",
            "多重射击伤害+20%，施放时有50%概率额外触发1次多重射击",
            "多重射击及其折射命中后施加[冰冷],持续5秒\n冰冷:减少10%移动速度,叠加至5层后冻结3秒",
            "多重射击伤害+30%，其箭矢命中后有50%的概率击退怪物一定距离",
            "每次施放多重射击，为该技能叠加攻击力+1%、法术强度+1，持续4秒，可叠加40次。",
            "施放多重射击时有20%概率召唤寒冰箭雨，对目标范围造成100%冰系伤害,并冻结目标1秒,持续5秒",
            "将多重射击升级为星辰之箭,每次命中目标后额外触发1次折射",
        ]
        self.assertEqual([rows[i]["description"] for i in sorted(rows)], descriptions)
        self.assertEqual(source, before)

    def test_invalid_rules_and_references(self):
        cases = [("combo_chance", 101), ("knock_chance", -1), ("rain_chance", True),
                 ("rain_ticks", 1.5), ("rain_interval_ms", 0), ("rain_ms", 4000),
                 ("rain_radius", float("nan")), ("copies", 5), ("pierce", 2),
                 ("focus_cap", 41), ("freeze_status", 999999), ("rain_skill", 999999),
                 ("spread_degrees", 0), ("spread_degrees", 181), ("spread_degrees", True), ("focus", 1), ("focus_status", 20403), ("unknown", 1)]
        for field, value in cases:
            source = copy.deepcopy(self.inputs[4])
            source["skills"]["20002"]["ice_arrows"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.compile(source)
        for field in ["chill_status", "rain_ms", "copies", "spread_degrees"]:
            source = copy.deepcopy(self.inputs[4])
            del source["skills"]["20002"]["ice_arrows"][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.compile(source)

    def test_modifiers_ownership_and_combined_limits(self):
        for mod in [{"spread_degrees": 8}, {"freeze_status": 20402}, {"upgraded": 1}, {"copies": 2}, {"combo_chance": 101}]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200403"]["ice_mod"] = mod
            with self.subTest(mod=mod), self.assertRaises(ValueError):
                self.compile(source)
        for parents in [[[999999, 1]], [[200, 1]], [[200409, 1]]]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200401"]["premise1"] = parents
            with self.subTest(parents=parents), self.assertRaises(ValueError):
                self.compile(source)
        source = copy.deepcopy(self.inputs[4])
        source["options"]["200401"]["aim_skill"] = [17]
        with self.assertRaises(ValueError):
            self.compile(source)
