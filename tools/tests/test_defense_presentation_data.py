import copy
import unittest

from tools import defense_pipeline as pipeline


class DefensePresentationDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference, cls.art, cls.combat, cls.rules, cls.hero_roster = pipeline.load_inputs()

    def test_result_reward_reference_rejects_unknown_icons_and_bad_counts(self):
        pipeline.validate_result_rewards([])
        pipeline.validate_result_rewards(["resource:1:109", "resource:2:0"])
        for entries in [["resource:999:1"], ["hero:1:1"], ["resource:1:-1"], ["resource:1:1.5"], "resource:1:1"]:
            with self.subTest(entries=entries), self.assertRaisesRegex(ValueError, "result reward reference"):
                pipeline.validate_result_rewards(entries)

    def test_upgrade_quality_weights_use_current_source(self):
        self.assertEqual(pipeline.compile_loot(self.reference), {
            "quality_weights": [0, 2000, 4000, 3000, 1000],
        })

    def test_invalid_chest_weight_rejected(self):
        reference = copy.deepcopy(self.reference)
        row = next(r for r in reference["function_price"].values() if r["type"] == "skill_pro3")
        row["price"] = -1
        with self.assertRaisesRegex(ValueError, "invalid loot"):
            pipeline.compile_loot(reference)

    def test_chest_count_weights_have_exactly_four_nonzero_count_slots(self):
        result = pipeline.compile_catalog(self.reference, self.art, self.combat, self.rules, self.hero_roster)
        self.assertEqual(result["rules"]["chest_reward_weights"], [50, 30, 15, 5])
        self.assertNotIn("boss_count_weights", result["loot"])
        for value in [[], [1, 2, 3], [1, 2, 3, 4, 5], [0, 0, 0, 0], [1, 1, -1, 1], [True, 1, 1, 1], [1.5, 1, 1, 1]]:
            rules = copy.deepcopy(self.rules)
            rules["chest_reward_weights"] = value
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "chest reward weights"):
                pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)

    def test_missing_patrol_boundary_rejected(self):
        combat = copy.deepcopy(self.combat)
        del combat["world"]["patrol_y"]
        with self.assertRaisesRegex(ValueError, "battle patrol lines"):
            pipeline.compile_catalog(self.reference, self.art, combat, self.rules, self.hero_roster)

    def test_reversed_patrol_boundaries_rejected(self):
        combat = copy.deepcopy(self.combat)
        combat["world"]["warning_y"] = 900
        with self.assertRaisesRegex(ValueError, "battle patrol lines"):
            pipeline.compile_catalog(self.reference, self.art, combat, self.rules, self.hero_roster)

    def test_obsolete_back_boundary_rejected(self):
        combat = copy.deepcopy(self.combat)
        combat["world"]["back_y"] = 800
        with self.assertRaisesRegex(ValueError, "battle patrol lines"):
            pipeline.compile_catalog(self.reference, self.art, combat, self.rules, self.hero_roster)

    def test_all_zero_quality_weights_rejected(self):
        reference = copy.deepcopy(self.reference)
        for row in reference["function_price"].values():
            if row["type"] in [f"skill_pro{i}" for i in range(1, 6)]:
                row["price"] = 0
        with self.assertRaisesRegex(ValueError, "invalid loot"):
            pipeline.compile_loot(reference)


    def test_invalid_chest_quality_rejected(self):
        reference = copy.deepcopy(self.reference)
        reference["upgrade_options"]["2"]["icon"] = "25:6"
        with self.assertRaisesRegex(ValueError, "invalid chest quality"):
            pipeline.compile_catalog(reference, self.art, self.combat, self.rules, self.hero_roster)

    def test_missing_home_sprite_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing required sprite home:missing"):
            pipeline.validate_home_art(self.art, 'resource_key = "home:missing"\n')

    def test_baked_home_atlas_page_rejected(self):
        with self.assertRaisesRegex(ValueError, "not baked atlas page paths"):
            pipeline.validate_home_art(self.art, '[ext_resource path="res://assets/runtime/defense/atlas_10.png"]')

    def test_home_bindings_checked_against_current_art(self):
        scene = (pipeline.ROOT / "scenes/defense/home.tscn").read_text(encoding="utf-8")
        pipeline.validate_home_art(self.art, scene)
        art = copy.deepcopy(self.art)
        del art["sprites"]["home:home_level_bg_1"]
        with self.assertRaisesRegex(ValueError, "missing required sprite home:home_level_bg_1"):
            pipeline.validate_home_art(art, scene)

    def test_other_scene_cannot_bake_an_atlas_region(self):
        with self.assertRaisesRegex(ValueError, "logical sprite keys"):
            pipeline.validate_presentation_art(self.art, {"pause.tscn": '[sub_resource type="AtlasTexture"]\nregion = Rect2(1, 2, 3, 4)'})

    def test_other_script_cannot_draw_raw_atlas_pages(self):
        with self.assertRaisesRegex(ValueError, "only by DefenseAtlas"):
            pipeline.validate_presentation_art(self.art, {"pause.gd": 'draw_texture_rect_region(atlas.pages[1], rect, region)'})

    def test_other_interface_missing_named_art_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing required sprite map:missing"):
            pipeline.validate_presentation_art(self.art, {"hud.gd": 'atlas.picture(self, "map:missing", rect)'})

    def test_ui_content_region_follows_new_page_position_and_size(self):
        art = copy.deepcopy(self.art)
        art["sprites"]["map:speedUp4"] = {"page": 2, "rect": [300, 400, 810, 770], "size": [810, 770], "offset": [0, 0]}
        updated = pipeline.ui_art(art)
        self.assertEqual(updated["sprites"]["map:speedUp4_face"],
                         {"page": 2, "rect": [320, 410, 650, 610], "size": [650, 610], "offset": [0, 0]})
        self.assertNotIn("map:speedUp4_face", art["sprites"], "UI compilation must not modify source definitions")

    def test_changed_or_unregistered_atlas_page_rejected(self):
        expected = {"atlas.png": "export_hash"}
        pipeline.validate_export_hashes(expected, {"atlas.png": "export_hash"})
        with self.assertRaisesRegex(ValueError, "page/index export mismatch"):
            pipeline.validate_export_hashes(expected, {"atlas.png": "new_pixels"})
        with self.assertRaisesRegex(ValueError, "page/index export mismatch"):
            pipeline.validate_export_hashes(expected, {"new_page.png": "export_hash"})

    def test_invalid_sprite_page_and_bounds_rejected(self):
        art = {"pages": ["page"], "sprites": {"ui:button": {"page": 0, "rect": [8, 9, 20, 21], "offset": [0, 0], "size": [20, 21]}}}
        pipeline.validate_sprite_regions(art, [(32, 32)])
        art["sprites"]["ui:button"]["page"] = 1
        with self.assertRaisesRegex(ValueError, "invalid atlas page"):
            pipeline.validate_sprite_regions(art, [(32, 32)])
        art["sprites"]["ui:button"]["page"] = 0
        with self.assertRaisesRegex(ValueError, "invalid atlas region"):
            pipeline.validate_sprite_regions(art, [(16, 16)])

    def test_unknown_skill_icon_rejected(self):
        reference = copy.deepcopy(self.reference)
        reference["upgrade_options"]["1"]["icon"] = "missing:1"
        with self.assertRaisesRegex(ValueError, "unknown icon missing"):
            pipeline.compile_catalog(reference, self.art, self.combat, self.rules, self.hero_roster)

    def test_missing_skill_image_rejected(self):
        art = copy.deepcopy(self.art)
        icon = self.reference["skill_icon"]["21"]["icon"]
        del art["sprites"]["gameIcon:" + icon]
        with self.assertRaisesRegex(ValueError, "missing icon sprite"):
            pipeline.compile_catalog(self.reference, art, self.combat, self.rules, self.hero_roster)

    def test_missing_tag_image_rejected(self):
        art = copy.deepcopy(self.art)
        del art["sprites"]["gameIcon:heroType6"]
        with self.assertRaisesRegex(ValueError, "missing tag icon"):
            pipeline.compile_catalog(self.reference, art, self.combat, self.rules, self.hero_roster)

    def test_invalid_action_timing_rejected(self):
        combat = copy.deepcopy(self.combat)
        combat["actors"]["hero:1"]["frames"]["attack"][0] = -1
        with self.assertRaisesRegex(ValueError, "invalid actor action timing"):
            pipeline.compile_catalog(self.reference, self.art, combat, self.rules, self.hero_roster)

    def test_invalid_formation_rejected(self):
        combat = copy.deepcopy(self.combat)
        combat["formation"]["front"][1] = [[800, 950]]
        with self.assertRaisesRegex(ValueError, "invalid hero formation"):
            pipeline.compile_catalog(self.reference, self.art, combat, self.rules, self.hero_roster)

    def test_invalid_revival_timing_rejected(self):
        rules = copy.deepcopy(self.rules)
        rules["revive_seconds"]["2"] = -1
        with self.assertRaisesRegex(ValueError, "invalid profession revival timing"):
            pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)

    def test_invalid_experience_rules_rejected(self):
        for key, value, error in [
            ("hero_limit", 4, "experience limits"),
            ("max_level", 21, "experience limits"),
            ("recruit_chance", 10001, "recruitment chance"),
            ("recruit_chance", -1, "recruitment chance"),
            ("recruit_chance", 2500.5, "recruitment chance"),
            ("schema_version", 5, "experience rules schema"),
            ("hero_spawn", [800, 1600], "hero spawn"),
            ("formation_five", {"front": [[800, 950]] * 5, "back": [[800, 1150]] * 5}, "five hero formation"),
        ]:
            rules = copy.deepcopy(self.rules)
            rules[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, error):
                pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)

    def test_unknown_profession_and_boss_rejected(self):
        reference = copy.deepcopy(self.reference)
        reference["lead"]["1"]["label"][1] = 99
        with self.assertRaisesRegex(ValueError, "unknown profession"):
            pipeline.compile_catalog(reference, self.art, self.combat, self.rules, self.hero_roster)
        reference = copy.deepcopy(self.reference)
        reference["level_details"][3]["encounters"][0]["monster_id"] = 999999
        with self.assertRaisesRegex(ValueError, "missing encounter"):
            pipeline.compile_catalog(reference, self.art, self.combat, self.rules, self.hero_roster)

    def test_invalid_encounter_rows_rejected(self):
        for row in [None, {}, {"kind": "normal"}, {"kind": "unknown", "monster_id": 114}]:
            reference = copy.deepcopy(self.reference)
            reference["level_details"][3]["encounters"][0] = row
            with self.subTest(row=row), self.assertRaisesRegex(ValueError, "invalid encounter inputs"):
                pipeline.compile_catalog(reference, self.art, self.combat, self.rules, self.hero_roster)

    def test_obsolete_fixed_recruitment_schema_rejected(self):
        rules = copy.deepcopy(self.rules)
        rules["schema_version"] = 1
        rules["recruit_levels"] = [1, 2, 4, 6, 8]
        del rules["recruit_chance"]
        with self.assertRaisesRegex(ValueError, "experience rules schema"):
            pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)

    def test_compiled_experience_rules_and_source_isolation(self):
        reference = copy.deepcopy(self.reference)
        combat = copy.deepcopy(self.combat)
        result = pipeline.compile_catalog(reference, self.art, combat, self.rules, self.hero_roster)
        self.assertEqual(result["schema_version"], 14)
        self.assertEqual(result["rules"]["recruit_chance"], 2500)
        self.assertNotIn("recruit_levels", result["rules"])
        self.assertNotIn("revival", result["combat"])
        self.assertFalse(any(o.get("isNew", 0) < 0 for o in result["options"].values()))
        for level in result["levels"].values():
            self.assertEqual(len(level["waves"]), 20)
            self.assertTrue(all("entries" in wave for wave in level["waves"]))
            self.assertTrue(all("enemy_pool" not in wave and "weights" not in wave for wave in level["waves"]))
            self.assertNotIn("bosses", level)
            self.assertEqual(sum(w["count"] for w in level["waves"]), sum(e["count"] for w in level["waves"] for e in w["entries"]))
        for hero in result["heroes"].values():
            self.assertEqual(hero["base"]["23"], self.rules["revive_seconds"][str(hero["profession"])])
        self.assertEqual(combat, self.combat)
        self.assertEqual(reference, self.reference)

    def test_initial_roster_and_invalid_unlock_rules(self):
        result = pipeline.compile_catalog(self.reference, self.art, self.combat, self.rules, self.hero_roster)
        self.assertEqual(result["rules"]["unlocked_heroes"], [1, 2, 4, 13, 17])
        self.assertEqual([result["heroes"][str(h)]["name"] for h in result["rules"]["unlocked_heroes"]],
                         ["火焰术士", "德鲁伊", "勇者", "寒冰射手", "闪电刺客"])
        for value in [[], [1, 1], ["1"], [True], [0], [999], [18]]:
            rules = copy.deepcopy(self.rules)
            rules["unlocked_heroes"] = value
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "unlocked hero"):
                pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)
        rules = copy.deepcopy(self.rules)
        rules["schema_version"] = 2
        del rules["unlocked_heroes"]
        with self.assertRaisesRegex(ValueError, "experience rules schema"):
            pipeline.compile_catalog(self.reference, self.art, self.combat, rules, self.hero_roster)

    def test_single_initial_skill_ownership_and_removed_trees(self):
        reference = copy.deepcopy(self.reference)
        source = copy.deepcopy(self.hero_roster)
        result = pipeline.compile_catalog(reference, self.art, self.combat, self.rules, source)
        expected = {hid: [profile["option"]] for hid, profile in self.hero_roster["heroes"].items()}
        for hid, roots in expected.items():
            self.assertEqual(result["heroes"][hid]["initial_options"], roots)
            self.assertNotIn("initial_option", result["heroes"][hid])
            for root in roots:
                option = result["options"][str(root)]
                self.assertEqual(option["options_num"], 1 if hid in self.hero_roster["option_sets"] else 0)
                self.assertEqual(option["type"], [int(hid)])
            for option in result["options"].values():
                if option.get("type") != [int(hid)]:
                    continue
                self.assertIn(option["root_option"], roots)
                for condition in option.get("premise1", []) + option.get("premise2", []):
                    self.assertIn(str(condition[0]), result["options"])
        for oid in [14, 31, 76, 77, 85, 89, 316, 321, 329, 602, 606, 610, 1085, 1089]:
            self.assertNotIn(str(oid), result["options"])
        self.assertEqual(result["skills"]["17"]["cd"], 6000)
        self.assertEqual(result["skills"]["20301"]["cd"], 15000)
        self.assertEqual(result["skills"]["1435"]["cd"], 8000)
        for oid in [2, 1081, 601]:
            self.assertNotIn(str(oid), list(result["options"]))
        self.assertEqual(result["options"]["495"]["type"], [6])
        self.assertEqual(result["options"]["801"]["type"], [9])
        self.assertEqual(reference, self.reference)
        self.assertEqual(source, self.hero_roster)

    def test_invalid_roster_source_rejected(self):
        cases = []
        for field, value in [("option", 999999), ("trigger", 999999), ("groups", [999999]), ("groups", [21, 21]), ("equip_skill", ["999999:1"]), ("name", ""), ("race", "unknown"), ("element", "unknown"), ("attack_delay_ms", 0), ("attack_delay_ms", True), ("damage_type", "0;107")]:
            source = copy.deepcopy(self.hero_roster)
            source["heroes"]["1"][field] = value
            cases.append(source)
        source = copy.deepcopy(self.hero_roster)
        del source["heroes"]["2"]
        cases.append(source)
        source = copy.deepcopy(self.hero_roster)
        source["schema_version"] = 0
        cases.append(source)
        for group, key, patch in [("skills", "17", {"cd": -1}), ("skills", "17", {"aim": [99999]}), ("skills", "17", {"statusChange": [["99999", "1"]]}), ("skills", "17", {"skillGroupType": [[1,99999]]}), ("options", "99999", {"description": "bad"})]:
            source = copy.deepcopy(self.hero_roster)
            source[group][key] = patch
            cases.append(source)
        for index, source in enumerate(cases):
            with self.subTest(case=index), self.assertRaises(ValueError):
                pipeline.compile_catalog(self.reference, self.art, self.combat, self.rules, source)

    def test_skill_activation_and_visual_fields_reject_invalid_values(self):
        for field, values in {
            "cast_range": [0, -1, True, "400", None, float("nan"), float("inf")],
            "visual_tint": [None, 123, "cyan", "#fff", "#72d8ff00", "#gggggg"],
        }.items():
            for value in values:
                source = copy.deepcopy(self.hero_roster)
                source["skills"]["755"][field] = value
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "invalid (cast range|visual tint)"):
                    pipeline.compile_catalog(self.reference, self.art, self.combat, self.rules, source)
