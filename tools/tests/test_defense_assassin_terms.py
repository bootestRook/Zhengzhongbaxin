import copy
import hashlib
import unittest

from tools import defense_pipeline as pipeline


class AssassinTermsDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def compile(self, source):
        return pipeline.compile_catalog(*self.inputs[:4], source)

    def test_library_and_immutable_source(self):
        source = copy.deepcopy(self.inputs[4])
        before = copy.deepcopy(source)
        c = self.compile(source)
        rows = [c["options"][str(i)] for i in range(200500, 200509)]
        self.assertEqual(c["heroes"]["17"]["initial_options"], [200500])
        self.assertEqual([r["term_id"] for r in rows], list(range(500, 509)))
        self.assertEqual([r["title"] for r in rows], ["刺杀", "增伤", "连击", "麻痹", "烟幕弹", "刀扇", "追猎", "感电", "即死"])
        self.assertEqual([r["draw_weight"] for r in rows], [5000, 3000, 3000, 2000, 2000, 2000, 1000, 1000, 2000])
        self.assertEqual([r["options_num"] for r in rows], [1, 2, 1, 1, 1, 1, 1, 1, 1])
        self.assertEqual(rows[5]["premise1"], [[200503, 1]])
        self.assertEqual(rows[6]["premise1"], [[200502, 1]])
        self.assertEqual(rows[8]["premise1"], [[200501, 1], [200506, 1]])
        descriptions = [
            "立即传送至1名怪物位置并攻击目标,对其造成300%电系伤害",
            "刺杀伤害+80%",
            "刺杀额外造成1次伤害",
            "刺杀命中目标后使其处于[麻痹]状态,持续2秒",
            "传送至目标位置后立即投掷烟幕弹，对范围内怪物造成伤害并使其命中-50%，持续4秒",
            "传送至目标后向周围释放刀扇造成100%电系伤害，并使其处于[麻痹]状态,持续1秒",
            "刺杀击杀目标后冷却时间立即重置，并使下次刺杀伤害+50%",
            "普攻对目标附加[感电]状态,持续5秒\n感电:每秒造成30%电系伤害，最多叠加5层",
        ]
        self.assertEqual([r["description"] for r in rows[:8]], descriptions)
        self.assertEqual(rows[8]["description"], "刺杀无视目标护甲,若目标生命值低于20%则立即斩杀目标; 若目标为精英或首领则造成3倍伤害")
        self.assertEqual(c["skills"]["1435"]["assassination"]["elite_multiplier"], 3)
        for oid in [614, 615, 616, 617, 621, 631, 632, 633]:
            self.assertNotIn(str(oid), c["options"])
        self.assertEqual(c["skills"]["1435"]["skillGroupType"], [])
        self.assertEqual(source, before)

    def test_bad_parameters_references_and_ownership(self):
        for key, value in [("smoke_radius", -1), ("damage_percent", 0), ("fan_ms", 1.5),
                           ("combo", 1), ("hunt_bonus", float("nan")), ("execute_threshold", 100),
                           ("shock_status", 999999), ("elite_multiplier", 0), ("elite_multiplier", float("inf")), ("unknown", 1)]:
            s = copy.deepcopy(self.inputs[4])
            s["skills"]["1435"]["assassination"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.compile(s)
        for value in [{}, [], {"unknown": 1}, {"combo": 1}, {"paralyze_status": 20501}]:
            s = copy.deepcopy(self.inputs[4])
            s["options"]["200501"]["assassination_mod"] = value
            with self.subTest(mod=value), self.assertRaises(ValueError):
                self.compile(s)
        for field, value in [("aim_skill", [17]), ("premise1", [[200201, 1]]),
                             ("premise1", [[999999, 1]]), ("premise1", [[200508, 1]]),
                             ("draw_weight", 0), ("options_num", 3)]:
            s = copy.deepcopy(self.inputs[4])
            s["options"]["200501"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.compile(s)
        s = copy.deepcopy(self.inputs[4])
        s["options"]["200508"]["assassination_mod"]["execute_threshold"] = 90
        with self.assertRaises(ValueError):
            self.compile(s)

    def test_other_heroes_and_frozen_reference_unchanged(self):
        baseline = pipeline.read(pipeline.ROOT / "validation/defense/assassin_terms/baseline.json")
        c = self.compile(copy.deepcopy(self.inputs[4]))
        source = copy.deepcopy(self.inputs[4])
        source["skills"]["1435"]["assassination"]["damage_percent"] += 1
        source["options"]["200501"]["assassination_mod"]["damage_percent"] += 1
        changed = self.compile(source)
        self.assertNotEqual(c["skills"]["1435"], changed["skills"]["1435"])
        # Assert isolation against the current roster; historical other-hero
        # fingerprints must not prohibit later authorized hero revisions.
        for table in ["heroes", "options", "skills"]:
            for key, row in c[table].items():
                owned = key == "17" if table == "heroes" else 17 in row.get("type", []) if table == "options" else key == "1435"
                if not owned:
                    self.assertEqual(row, changed[table][key], (table, key))
        for table in ["statuses", "targets"]:
            self.assertEqual(c[table], changed[table])
        self.assertEqual(hashlib.sha256((pipeline.SOURCE / "reference.json").read_bytes()).hexdigest(), baseline["reference_sha256"])
