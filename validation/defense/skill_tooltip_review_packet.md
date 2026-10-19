# Skill description fix review packet

Native Windows Godot 4.7.1; 960x1920 logical canvas, keep aspect. No web detector ran. Scope is this skill description fix and immediate regressions, not a renewed audit of all battle/home/choice visuals.

User rejected the prior build with two screenshots and asks: 1 点击这里不应该停止; 2 应该显示对应的技能描述. The pointed control is the bottom circular initial-skill icon, distinct from the portrait. Reference 2 shows a white paper speech bubble with black Chinese skill description above the clicked circle, also while the three-choice UI is open.

User screenshots:
C:/Users/Arche/AppData/Local/Temp/codex-clipboard-26b1f709-63e2-4ab2-adba-d9c6045a337c.png
C:/Users/Arche/AppData/Local/Temp/codex-clipboard-3fef3733-e69d-4e50-ba5e-cf95feab4a16.png

Build: root roster Control contains fixed Portrait and Skill Buttons. Portrait keeps existing attribute inspection behavior. Skill routes to a new fixed SkillTooltip instance; descriptions resolve the displayed initial skill's option from the clicked hero definition. Toggle, another skill, paper click, outside click and Escape dismiss/change the popup without a pause intent. Choice inspections preserve candidate state; no native hover text covers the skill row. White frame uses existing map:tips2 nine-slice texture and a geometric speech pointer. Its width is 680, text36 with smart wrapping; height follows actual content, X clamps to viewport. Fixed nodes are tscn, no new rules/dependencies or runtime data mutations.

Artifacts: scenes/main.tscn; scenes/defense/roster_card.tscn; scenes/defense/skill_tooltip.tscn; src/features/defense/presentation/defense_view.gd, defense_roster_card.gd, defense_skill_tooltip.gd. Test: tests/test_defense_battle_ui.gd. Capture: validation/defense/capture_skill_tooltip.gd.

Nine required native screenshots in F:/T8demo/T8-demo-16/validation/defense:
skill_tooltip_battle_720.png, skill_tooltip_battle_960.png, skill_tooltip_battle_540.png
skill_tooltip_right_720.png, skill_tooltip_right_960.png, skill_tooltip_right_540.png
skill_tooltip_choice_720.png, skill_tooltip_choice_960.png, skill_tooltip_choice_540.png

Native capture uses real viewport mouse clicks and public gameplay APIs to recruit four heroes / offer skill upgrades. It stops app automatic stepping only to stabilize captures; full gameplay-clock assertions are in actual mouse-chain tests. Numbers and hero composition differ from the reference by actual state. Evaluate visibility, layering, paper material, readable Chinese, pointer position, no overlap/clipping of descriptions and reachable controls. Text should be only the corresponding description, no unrelated hero attributes or native hover hint.

Quality bar: preserve the existing ink/forest/paper world; make the requested control work without interrupting gameplay; correct per-hero description; all four positions and three sizes usable; no full-screen modal shade; dismissals preserve paused state. Return full reviewer contract and one disposition at this scope. Save report validation/defense/skill_tooltip_visual_review.md; do not edit implementation.

Asset provenance scan: 15 rasters, zero missing. No new bitmap asset was created for the product. The screenshot/contact sheet is diagnostic evidence only.

Latest full Godot runner passes 20136 assertions, including the native input / rule-clock checks. Final project gate is pending.
