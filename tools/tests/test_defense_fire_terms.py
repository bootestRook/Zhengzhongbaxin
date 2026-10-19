import copy
import unittest

from tools import defense_pipeline as pipeline


class FireTermsDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def compile(self, source):
        return pipeline.compile_catalog(*self.inputs[:4], source)

    def test_library_original_copy_and_weights(self):
        source = copy.deepcopy(self.inputs[4])
        before = copy.deepcopy(source)
        result = self.compile(source)
        rows = {int(k): v for k, v in result["options"].items() if v["type"] == [1]}
        self.assertEqual(sorted(rows), list(range(200, 211)))
        self.assertEqual(result["heroes"]["1"]["initial_options"], [200])
        self.assertEqual([rows[i]["draw_weight"] for i in rows],
                         [5000, 3000, 3000, 2000, 2000, 2000, 1000, 1000, 1000, 1000, 2000])
        descriptions = [
            "短暂蓄力后释放1个火球对目标范围造成100%火系爆炸伤害",
            "爆炸伤害+60%", "爆炸范围+80%",
            "爆炸伤害+40%，并施加持续5秒的引燃效果\n引燃:每秒造成100%火系伤害",
            "爆炸伤害+40%，爆炸范围产生持续3秒的余烬\n余烬:对范围内的敌人每秒造成100%火系伤害",
            "爆炸后会额外产生一次更大范围伤害更低的爆炸,造成50%伤害",
            "蓄力时间延长50%，同步蓄力数量+1",
            "蓄力时获得自身生命25%护盾，同步蓄力数量+1",
            "每10点攻击速度使火球术伤害+1%",
            "爆炸伤害+50%，并会施加2秒晕眩效果",
            "将火球术升级为炎爆术,穿透+2，每次命中都会爆炸",
        ]
        for i, description in enumerate(descriptions, 200):
            self.assertEqual(rows[i]["description"], description)
            self.assertEqual(rows[i]["options_num"], 1)
        self.assertEqual(rows[210]["premise1"], [[201, 1], [202, 1]])
        self.assertEqual(rows[207]["premise1"], [[206, 1]])
        self.assertEqual(source, before)

    def test_invalid_capability_fields_and_references_rejected(self):
        bad = [("copies", x) for x in [0, True, 1.5, 17]]
        bad += [("spread_degrees", 0), ("spread_degrees", 181), ("spread_degrees", True), ("charge_ms", -1), ("pierce", 17), ("upgraded", 1),
                ("speed_conversion", float("nan")), ("shield_percent", 101),
                ("projectile", 999999), ("burn_status", 999999), ("unknown", 1)]
        for key, value in bad:
            source = copy.deepcopy(self.inputs[4])
            source["skills"]["17"]["fireball"][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.compile(source)
        for value in [[], {"spread_degrees": 6}, {"blast": 22}, {"copies": -1}, {"secondary": 1}]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["201"]["fireball_mod"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.compile(source)

    def test_missing_required_fields_and_wrong_owner_rejected(self):
        for field in ["copies", "charge_ms", "ember", "burn_status", "spread_degrees"]:
            source = copy.deepcopy(self.inputs[4])
            del source["skills"]["17"]["fireball"][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.compile(source)
        for parents in [[[999999, 1]], [[81, 1]], [[210, 1]]]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["201"]["premise1"] = parents
            with self.subTest(parents=parents), self.assertRaises(ValueError):
                self.compile(source)

    def test_periodic_contract_flags_reject_non_boolean(self):
        for group, key, fields in [("skills", "20201", ["periodic", "persistent_area"]),
                                   ("statuses", "20201", ["refresh_ticks", "tick_at_expiry"])]:
            for field in fields:
                source = copy.deepcopy(self.inputs[4])
                source[group][key][field] = "true"
                with self.subTest(field=field), self.assertRaises(ValueError):
                    self.compile(source)
