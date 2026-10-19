import copy
import unittest

from tools import defense_pipeline as pipeline


class WarriorTermsDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = pipeline.load_inputs()

    def compile(self, source):
        return pipeline.compile_catalog(*self.inputs[:4], source)

    def test_complete_library_and_frozen_reference(self):
        source = copy.deepcopy(self.inputs[4])
        before = copy.deepcopy(source)
        result = self.compile(source)
        rows = [row for row in result["options"].values() if row["type"] == [4]]
        self.assertEqual(sorted(row["id"] for row in rows), list(range(200100, 200108)))
        self.assertEqual(sorted(row["term_id"] for row in rows), list(range(100, 108)))
        self.assertEqual([result["options"][str(i)]["draw_weight"] for i in range(200100, 200108)],
                         [5000, 3000, 3000, 4000, 3000, 1000, 4000, 4000])
        self.assertEqual(result["options"]["200106"]["premise1"], [[200105, 1], [200104, 1]])
        self.assertEqual(result["options"]["200107"]["premise1"], [[200106, 1], [200101, 1]])
        self.assertEqual(result["options"]["200101"]["guard"]["hurt_interval_ms"], 500)
        for oid in [100, 101, 102]:
            self.assertNotIn(str(oid), result["options"])
        self.assertEqual(source, before)

    def test_rejects_invalid_weights_and_guard_rules(self):
        cases = [("draw_weight", value) for value in [0, -1, True, "3000", float("nan")]]
        cases += [("guard", value) for value in [[], {}, {"unknown": 1}, {"status": 999999},
                  {"hurt_step": 1}, {"hurt_step": 1, "hurt_cap": 10, "hurt_interval_ms": 0},
                  {"control_multiplier": 1.5}, {"knockback_immune": 1}, {"immunity_ms": 2000}, {"taunt_skill": 999999}]]
        cases += [("term_type", "bad"), ("term_id", 0), ("duration_up", -1), ("icon", "999999:3")]
        cases += [("options_num", True), ("description_template", "{missing}")]
        for field, value in cases:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200101"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.compile(source)

    def test_original_warrior_descriptions_are_preserved(self):
        descriptions = {
            200100: "释放圣盾，嘲讽周围目标并使自身受到伤害-50%，持续4秒",
            200101: "圣盾持续期间，每受到1次伤害，减伤额外提升1%，最多提升10%；本次圣盾结束时清除",
            200102: "圣盾冷却时间-10%",
            200103: "嘲讽范围+30%",
            200104: "圣盾持续时间增加2秒",
            200105: "被嘲讽目标攻击力-15%",
            200106: "圣盾期间免疫击退，受到控制时间-50%",
            200107: "圣盾期间受到致命伤害时，保留1点生命，并获得2秒伤害免疫。每60秒最多触发1次",
        }
        result = self.compile(copy.deepcopy(self.inputs[4]))
        for oid, description in descriptions.items():
            with self.subTest(option=oid):
                self.assertEqual(result["options"][str(oid)]["description"], description)

    def test_rejects_collisions_missing_cross_owner_and_cyclic_dependencies(self):
        cases = []
        source = copy.deepcopy(self.inputs[4])
        source["option_sets"]["4"].append(100)
        cases.append(source)
        source = copy.deepcopy(self.inputs[4])
        del source["options"]["200107"]
        cases.append(source)
        for parent in [999999, 81, 200102]:
            source = copy.deepcopy(self.inputs[4])
            source["options"]["200101"]["premise1"] = [[parent, 1]]
            if parent == 200102:
                source["options"]["200102"]["premise1"] = [[200101, 1]]
            cases.append(source)
        source = copy.deepcopy(self.inputs[4])
        source["options"]["200101"]["term_id"] = 100
        cases.append(source)
        for source in cases:
            with self.subTest(source=source["option_sets"]), self.assertRaises(ValueError):
                self.compile(source)
