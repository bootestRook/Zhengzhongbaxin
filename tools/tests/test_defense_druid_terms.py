import copy
import unittest

from tools import defense_pipeline as pipeline


class DruidTermsDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def compile(self, source):
        return pipeline.compile_catalog(*self.inputs[:4], source)

    def test_complete_library_copy_and_prerequisites(self):
        source = copy.deepcopy(self.inputs[4])
        before = copy.deepcopy(source)
        c = self.compile(source)
        terms = [301, 302, 303, 306, 307, 308, 310, 311, 312]
        rows = [c["options"][str(200000 + i)] for i in terms]
        self.assertEqual(c["heroes"]["2"]["initial_options"], [200301])
        self.assertEqual([r["term_id"] for r in rows], terms)
        self.assertEqual([r["draw_weight"] for r in rows], [5000, 4000, 4000, 2000, 3000, 1000, 4000, 4000, 3000])
        self.assertEqual([r["options_num"] for r in rows], [1, 2, 1, 1, 1, 1, 1, 1, 1])
        self.assertEqual(rows[5]["premise1"], [[200302, 1], [200303, 1]])
        self.assertEqual(rows[7]["premise1"], [[200303, 1], [200306, 1]])
        self.assertEqual(rows[8]["premise1"], [[200311, 1], [200310, 1]])
        descriptions = [
            "为英雄施加荆棘护甲，提供目标最大生命值5%的护盾并恢复攻击力120%的血量，使攻击其的怪物受到50%的自然伤害。荆棘护甲持续10秒。",
            "荆棘护甲持续+2.5秒；最多由10秒增至15秒",
            "施放荆棘护甲的直接治疗+50%；施放护甲时增加目标最大生命1.5%的护盾",
            "受荆棘护甲保护的友军受敌人直接攻击后附加缠根，使攻击者攻速降低5%，持续5秒。最高5层。",
            "施放荆棘护甲时在目标旁生成1株花灵，持续10秒。每5秒将200px圆形范围附近的怪物禁锢2s并造成自然伤害。",
            "荆棘护甲到期或被敌人击破时，爆炸对范围内敌人造成3秒眩晕",
            "花灵场上上限+1、持续+5秒；最终最多2株、持续15秒。超限时替换剩余时间最短者。",
            "每次施放荆棘护甲时，目标数量+1，无目标时保护自身。",
            "施放荆棘护甲时，至多2株现有花灵迁移到两名受护甲者身边，各治疗对应目标最大生命10%，并获得10秒30%减伤",
        ]
        self.assertEqual([r["description"] for r in rows], descriptions)
        self.assertIn("攻击力120%", rows[0]["description"])
        self.assertTrue(all("攻击力" not in r["description"] for r in rows[1:]))
        for oid in [81, 82, 83, 84, 94, 100, 101, 102]:
            self.assertNotIn(str(oid), c["options"])
        self.assertEqual(source, before)

    def test_terms_only_modify_the_owners_thorn_armor_skill(self):
        c = self.compile(copy.deepcopy(self.inputs[4]))
        for term in [302, 303, 306, 307, 308, 310, 311, 312]:
            row = c["options"][str(200000 + term)]
            self.assertEqual(row["aim_skill"], [20301])
            self.assertTrue(row["thorn_mod"])
        for field, value in [("aim_type", [0]), ("attribute_correct", ["4:50:1"]),
                             ("equip_skill", ["50:1"]), ("summon", ["23:1"]),
                             ("unlock", [749]), ("aim_skill", [])]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200303"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.compile(source)
        source = copy.deepcopy(self.inputs[4])
        source["options"]["200301"]["unlock"].append(749)
        with self.assertRaisesRegex(ValueError, "thorn armor"):
            self.compile(source)
        source = copy.deepcopy(self.inputs[4])
        source["heroes"]["2"]["equip_skill"] = ["50:1"]
        with self.assertRaisesRegex(ValueError, "thorn armor"):
            self.compile(source)
        source = copy.deepcopy(self.inputs[4])
        del source["options"]["200303"]["thorn_mod"]
        with self.assertRaisesRegex(ValueError, "thorn armor"):
            self.compile(source)

    def test_bad_configuration_references_counts_and_prerequisites(self):
        cases = [("flower_interval_ms", 0), ("targets", 3), ("flower_limit", 3),
                 ("armor_status", 999999), ("flower_template", 999999), ("flowers", 1),
                 ("heal_percent", float("nan")), ("flower_radius", -1), ("unknown", 1)]
        for key, value in cases:
            source = copy.deepcopy(self.inputs[4])
            source["skills"]["20301"]["thorn_armor"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.compile(source)
        for value in [0, 3, True, 1.5]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200302"]["options_num"] = value
            with self.subTest(count=value), self.assertRaises(ValueError):
                self.compile(source)
        for value in [[], {}, {"unknown": 1}, {"slow": 1}, {"duration_ms": -1}]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200302"]["thorn_mod"] = value
            with self.subTest(mod=value), self.assertRaises(ValueError):
                self.compile(source)
        for parents in [[[999999, 1]], [[200101, 1]], [[200308, 1]]]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200302"]["premise1"] = parents
            with self.subTest(parents=parents), self.assertRaises(ValueError):
                self.compile(source)
