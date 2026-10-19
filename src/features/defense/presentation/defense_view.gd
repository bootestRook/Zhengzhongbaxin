class_name DefenseView
extends Control

signal intent_requested(intent: String, payload: Dictionary)
const LevelButton = preload("res://scenes/defense/level_button.tscn")
var catalog
var atlas: DefenseAtlas
var current: Dictionary = {}
var notice_left: float = 0
const SKILL_HOLD_SECONDS = 0.4
var skill_hold_index: int = -1
var skill_hold_elapsed: float = 0
var skill_click_suppressed: bool = false

func configure(definitions) -> void:
	catalog = definitions
	atlas = DefenseAtlas.new(catalog.art())
	$Field.atlas = atlas
	$Field/ReviveEffects.field = $Field
	$Field/TombstoneEffects.field = $Field
	$ChoiceTransfer.atlas = atlas
	$ChoiceTransfer.field = $Field
	$ChoiceTransfer.roster = %HUD
	%HUD.atlas = atlas
	for background in [%HUD.get_node("RosterHeader"), %HUD.get_node("RosterPaper"), %HUD.get_node("RosterFooter")]:
		background.configure(atlas)
	$BattlePanels.configure(definitions, atlas)
	$HeroTerms.configure(definitions, atlas)
	$SkillTooltip.configure(atlas)
	$RewardPanel.configure(definitions, atlas)
	$RewardPanel.close_requested.connect(func(id): send("reward_close", {"id": id}))
	$BattlePanels.intent_requested.connect(send)
	$BattlePanels.damage_display_changed.connect(func(enabled): $Field.damage_numbers = enabled)
	%ChoicePanel.configure(definitions, atlas)
	%ChoicePanel.intent_requested.connect(send)
	%ChoicePanel.details_requested.connect(show_choice)
	%Home.configure(catalog, atlas)
	%Home.intent_requested.connect(home_intent)
	%Home.panel_requested.connect(func(title, text):
		%HomeInfoTitle.text = title
		%HomeInfoText.text = text
		%HomeInfoPanel.show())
	%HomeInfoClose.pressed.connect(func(): %HomeInfoPanel.hide())
	%LevelClose.pressed.connect(func(): %LevelPanel.hide())
	%Pause.pressed.connect(func(): send("pause"))
	%Speed.pressed.connect(func(): send("speed"))
	%BattleStats.pressed.connect(show_stats)
	%MonsterInfo.pressed.connect(show_monsters)
	%GemStats.pressed.connect(show_gems)
	%ResultPanel.configure(atlas)
	%ResultPanel.confirmed.connect(func(): send("home"))
	%ResultPanel.hero_requested.connect($BattlePanels.show_hero)
	for i in range(catalog.rules().hero_limit):
		get_node("HUD/Hero%d/Portrait" % i).pressed.connect(func(): show_terms(i))
		var skill_button = get_node("HUD/Hero%d/Skill" % i)
		skill_button.button_down.connect(func(): begin_skill_hold(i))
		skill_button.button_up.connect(func():
			if skill_hold_index == i:
				end_skill_hold())
		skill_button.mouse_exited.connect(func():
			if skill_hold_index == i:
				end_skill_hold(true))
		skill_button.pressed.connect(func():
			if not skill_click_suppressed:
				show_skill(i))
	for id in catalog.level_ids():
		var button = LevelButton.instantiate()
		button.text = str(id)
		button.pressed.connect(func():
			send("select_level", {"level": id})
			%LevelPanel.hide())
		%Levels.add_child(button)

func send(intent: String, payload: Dictionary = {}) -> void:
	end_skill_hold(true)
	$SkillTooltip.dismiss()
	$HeroTerms.dismiss()
	var selection: Dictionary = $ChoiceTransfer.prepare_selection(payload, %ChoicePanel, catalog) if intent == "choose" else {}
	intent_requested.emit(intent, payload)
	$ChoiceTransfer.confirm_selection(selection)

func home_intent(intent: String, payload: Dictionary) -> void:
	match intent:
		"levels":
			%LevelPanel.show()
		_:
			send(intent, payload)

func render(value: Dictionary) -> void:
	current = value
	$Field.snapshot = value
	if skill_hold_index >= 0 and not can_preview_skill(skill_hold_index):
		end_skill_hold(true)
	$Field/ReviveEffects.queue_redraw()
	$Field/TombstoneEffects.render(value)
	$ChoiceTransfer.render(value)
	%Home.visible = value.phase == "home"
	%HUD.visible = value.phase != "home"
	%ChoicePanel.render(value)
	$RewardPanel.render(value)
	$BattlePanels.render(value)
	$HeroTerms.render(value)
	$SkillTooltip.render(value)
	%ResultPanel.render(value)
	if value.phase == "home":
		%Home.render(value)
	%Wave.text = "第%d／%d波" % [value.wave, value.wave_count]
	%RunLevel.text = str(value.stage)
	%WaveDetail.text = "第%d关" % value.level
	%Progress.value = value.progress * 100
	%WallHealth.value = value.wall_hp / value.wall_max * 100
	%WallText.text = "%d" % value.wall_hp
	%Speed.tooltip_text = "战斗速度 ×%d" % value.speed
	%HUD.speed = int(value.speed)
	%HUD.choice = value.phase == "choice"
	%HUD.contribution = $BattlePanels/Contribution.visible
	%HUD.monsters = $BattlePanels/Monsters.visible
	%GemStats.visible = value.phase == "choice"
	%HUD.gem_entry = %GemStats.visible
	%MonsterInfo.visible = value.phase != "choice"
	for i in range(catalog.rules().hero_limit):
		get_node("HUD/Hero%d" % i).render(value.heroes[i] if i < value.heroes.size() else {}, atlas, value.time)
	%HUD.queue_redraw()

func show_notice(text: String) -> void:
	if %Home.visible and %Home.current_page == "statue":
		%Home.get_node("StatuePage").show_feedback(text)
		return
	%Notice.text = text
	notice_left = 3
	%Notice.visible = true

func show_terms(index: int) -> void:
	if index < 0 or index >= current.heroes.size() or current.phase in ["home", "result", "reward"]:
		return
	end_skill_hold(true)
	$SkillTooltip.dismiss()
	$BattlePanels.close_hero()
	$HeroTerms.open(int(current.heroes[index].id), current)

func show_skill(index: int) -> void:
	if index < 0 or index >= current.heroes.size() or current.phase in ["home", "result", "reward"]:
		return
	var skills: Array = current.heroes[index].skills
	if skills.is_empty():
		return
	var button = get_node("HUD/Hero%d/Skill" % index)
	$SkillTooltip.toggle(index, skills[0].description, button.get_global_rect())

func can_preview_skill(index: int) -> bool:
	return current.get("phase", "") == "playing" and not current.paused and index >= 0 and index < current.heroes.size() \
		and not current.heroes[index].dead and not current.heroes[index].skills.is_empty() \
		and float(current.heroes[index].skills[0].cast_range) > 0

func begin_skill_hold(index: int) -> void:
	end_skill_hold()
	skill_click_suppressed = false
	if can_preview_skill(index):
		skill_hold_index = index
		skill_hold_elapsed = 0

func end_skill_hold(cancelled: bool = false) -> void:
	if skill_hold_index >= 0 and (cancelled or $Field.range_hero_id != 0):
		skill_click_suppressed = true
	skill_hold_index = -1
	skill_hold_elapsed = 0
	$Field.range_hero_id = 0
	$Field.range_flow = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		end_skill_hold(true)

func show_choice(index: int) -> void:
	if current.phase != "choice" or current.paused or %ChoicePanel.busy or index < 0 or index >= current.offers.size():
		return
	$SkillTooltip.dismiss()
	$HeroTerms.dismiss()
	if current.offers[index].kind == "hero":
		var definition = catalog.record("heroes", int(current.offers[index].id))
		$BattlePanels.show_hero({"template": definition.id, "name": definition.name, "attributes": definition.base,
			"upgrades": definition.initial_options.duplicate(), "stats": {"damage": 0, "heal": 0, "taken": 0}})
		return
	for hero: Dictionary in current.heroes:
		if int(hero.id) == int(current.offers[index].owner):
			$BattlePanels.show_hero(hero)
			return

func show_stats() -> void:
	$BattlePanels.toggle_contribution()

func show_gems() -> void:
	$BattlePanels.show_gems()

func show_monsters() -> void:
	$BattlePanels.toggle_monsters()

func _process(delta: float) -> void:
	if skill_hold_index >= 0:
		skill_hold_elapsed += delta
		if skill_hold_elapsed >= SKILL_HOLD_SECONDS and $Field.range_hero_id == 0:
			skill_click_suppressed = true
			$SkillTooltip.dismiss()
			$Field.range_hero_id = int(current.heroes[skill_hold_index].id)
	if notice_left > 0:
		notice_left -= delta
		%Notice.visible = notice_left > 0

func _unhandled_key_input(event: InputEvent) -> void:
	if current.get("phase", "") == "reward":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if skill_hold_index >= 0:
			end_skill_hold(true)
		elif $HeroTerms.visible:
			$HeroTerms.dismiss()
			get_viewport().set_input_as_handled()
		elif $SkillTooltip.visible:
			$SkillTooltip.dismiss()
		elif $BattlePanels/BossDetails.visible:
			$BattlePanels/BossDetails.hide()
		elif $BattlePanels/Hero.visible:
			$BattlePanels.close_hero()
		elif $BattlePanels/Gems.visible:
			$BattlePanels/Gems.hide()
		elif $BattlePanels/Monsters.visible:
			$BattlePanels/Monsters.hide()
		elif $BattlePanels/Contribution.visible:
			$BattlePanels/Contribution.hide()
		elif %LevelPanel.visible:
			%LevelPanel.hide()
		elif %HomeInfoPanel.visible:
			%HomeInfoPanel.hide()
		elif current.get("phase", "") == "home" and %Home.current_page == "statue":
			%Home.get_node("StatuePage").escape()
		elif current.get("phase", "") == "home" and %Home.current_page == "heroes":
			%Home.show_page("battle")
		else:
			send("pause")
