# Battle UI review packet

Workspace: F:\T8demo\T8-demo-16. Native Windows Godot 4.7.1, 960×1920 logical canvas, keep aspect. No web detector ran. This is a reference-led local surface extension, not a new design world. Review screenshots at region scale, not just thumbnails.

User asks: 局内战斗场景需要1:1复刻图2，游戏正在雷电模拟器打开着. Added six surfaces: 1 暂停; 2 点击查看首领详情; 3 宝石属性; 4/5 点击英雄详情 i; 6/7 贡献度; 8 局内怪物详情. Existing three-choice entrance motion remains in scope as a regression.

Direction contract: use the supplied ink-outlined forest, paper cards, outlined type, central statue, thin full-width wall health and four portrait slots. Same source geometry at each portrait resolution. Pause keeps and blurs the underlying choice. Boss portrait opens its own readable detail. Hero i exposes attributes and expands/collapses. Contribution and monsters are live floating overlays; owned hero details preserve the previous pause state. All shown health, damage, cooldown, upgrades and attributes must read real domain state. Do not invent equipped runes or screenshot hero levels. The product fixes external progression to hero level 1 and no equipment/gem/rune bonus (PRODUCT.md / ADR-0002). Shortcut bubbles in the reference are emulator annotations.

Reference battle: C:\Users\Arche\AppData\Local\Temp\codex-clipboard-e451626e-404a-4ef2-92d7-4e73fb15da73.png

Reference surfaces (1 through 8):

1. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-ed48568c-a2e3-403c-ad95-18cf50700544.png
2. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-8625a857-59ba-49e1-b8d9-8eb7e7e5e876.png
3. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-37479dc8-a4be-4b5d-bbb8-4f84c98d75a5.png
4. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-3cf8a6b1-bbc6-4952-b7e1-3d075904a40e.png
5. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-cb0f42fb-fb09-4f68-b013-f5ba4ae34842.png
6. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-2bab2a22-e779-4cd3-9d30-4100b99d35c2.png
7. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-59435039-607a-49d0-bbab-40496dffffac.png
8. C:\Users\Arche\AppData\Local\Temp\codex-clipboard-9b9b07e9-a765-4cd0-baec-33853cf6dfdf.png

Build screenshots in F:\T8demo\T8-demo-16\validation\defense\:

- battle_reference_720.png / battle_reference_960.png / battle_reference_540.png
- pause_reference.png, boss_details.png, gem_attributes.png
- hero_details_collapsed.png, hero_details_expanded.png, owned_hero_details.png
- contribution_empty.png, contribution_live.png, battle_monsters.png
- Each surface also has _960.png and _540.png.

Captures use a native rendered window and real viewport mouse events. Capture script pauses app stepping for deterministic screenshots, recruits through the choice input chain, and adds a second hero / nearby enemy via public domain APIs for a live damage report. Different level/hero/bonus numbers are state differences; layout/style remains subject to 1:1 assessment. Source live capture: ldplayer_battle_live_0.png.

Changed artifact paths: scenes/main.tscn; scenes/defense/battle_panels.tscn, roster_card.tscn, monster_portrait.tscn, monster_row.tscn, contribution_row.tscn; src/features/defense/presentation/defense_battle_panels.gd, defense_field.gd, defense_hud.gd, defense_view.gd, defense_roster_card.gd; snapshots and frozen atlas metadata.

Validation: architecture lint passes. UI mouse tests cover reachable header buttons, modal close, boss details, pause/resume preserving offers, damage checkbox, candidate / owned attributes, expanded state, live health and initial-skill level, monster toggle, and quit. The latest full Godot suite passes 1088 assertions. Final project check remains a separate delivery gate and must use the current source fingerprint.

Quality bar: graphical fidelity to reference, legible CJK and numbers at 540, no truncated descriptions, real input/state behavior, coherent layering and pause/choice behavior, and no fake progression/bonuses. Return exactly one disposition: recapture / rebuild / fix / ship, with bounded material findings and their screenshot/file evidence. Do not edit files. Use the skill's native-context finish workflow.
