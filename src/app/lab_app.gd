extends Control

const Lab = preload("res://src/features/defense/domain/lab/battle_lab.gd")
const Inspector = preload("res://src/features/defense/domain/lab/lab_inspector.gd")
const Overlay = preload("res://scenes/defense/lab_overlay.tscn")
const LabPanel = preload("res://src/features/defense/presentation/lab/lab_panel.gd")
const Files = preload("res://src/platform/lab_files.gd")
var lab
var panel
var game
var overlay
var clock_credit: float = 0
var ui_credit: float = 0
var rates: Array = [0.25, 0.5, 1.0, 2.0, 3.0]
var boot_error: String = ""
var file_mode: String = ""
var runtime_fingerprint: String = ""

func _ready() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1360, 1000)
	DisplayServer.window_set_min_size(Vector2i(720, 640))
	DisplayServer.window_set_title("战斗测试场 · 当前战斗场景")
	game = %Game
	game.set_process(false)
	if not game.is_ready_for_use():
		boot_error = game.boot_error
		%Notice.text = boot_error
		return
	lab = Lab.new(game._catalog)
	game.session.dispose()
	game.session = lab.world
	var view = game.get_node("DefenseView")
	view.intent_requested.disconnect(game.submit)
	view.intent_requested.connect(on_game)
	overlay = Overlay.instantiate()
	view.add_child(overlay)
	overlay.offset = Vector2(-320, -227)
	overlay.point_selected.connect(on_field)
	panel = LabPanel.new(self)
	panel.configure()
	%Play.pressed.connect(func(): dispatch("pause", {}))
	%Step.pressed.connect(func(): single_step(1))
	%Second.pressed.connect(func(): single_step(100))
	%Next.pressed.connect(func():
		dispatch("pause", {"paused": true})
		var kinds = ["windup", "damage", "death"]
		show_result(lab.step_to(kinds[%Event.selected], 1250), "已推进到目标事件")
		refresh())
	%Reset.pressed.connect(func(): dispatch("reset"))
	%Tools.pressed.connect(func(): %ToolPanel.visible = not %ToolPanel.visible; fit_battle())
	%Geometry.toggled.connect(func(enabled): overlay.debug_shapes = enabled)
	%FileDialog.file_selected.connect(file_selected)
	%BattleFrame.resized.connect(fit_battle)
	runtime_fingerprint = Files.fingerprint()
	var args = OS.get_cmdline_user_args()
	var index = args.find("--case")
	if index >= 0 and index + 1 < args.size(): load_path(args[index + 1], false)
	else: panel.load_preset()
	await get_tree().process_frame
	fit_battle()
	refresh()

func dispatch(action: String, payload: Dictionary = {}) -> void:
	var previous = lab.world
	var error: String = lab.submit(action, payload)
	game.session = lab.world
	if previous != lab.world: panel.reset_view()
	clock_credit = 0
	show_result(error, "已应用；词条或配置变更会重建战场" if action in ["term", "configure"] else "操作已生效")
	refresh()

func on_game(intent: String, payload: Dictionary) -> void:
	if intent == "home":
		dispatch("reset")
		return
	dispatch("game", {"intent": intent, "payload": payload})
	if intent == "speed": %Rate.select(rates.find(float(lab.world.speed)))

func single_step(ticks: int) -> void:
	dispatch("pause", {"paused": true})
	dispatch("advance", {"ticks": ticks})

func show_result(error: String, success: String) -> void:
	%Notice.text = success if error.is_empty() else error
	%Notice.modulate = Color("33462e") if error.is_empty() else Color("ad3327")

func _process(delta: float) -> void:
	if lab == null: return
	if not lab.world.paused and lab.world.phase == "playing":
		clock_credit += minf(delta, 0.25) * float(rates[%Rate.selected])
		var ticks = floori(clock_credit / 0.016)
		if ticks > 0:
			lab.submit("advance", {"ticks": ticks})
			clock_credit -= ticks * 0.016
	var value: Dictionary = lab.world.snapshot()
	game.session = lab.world
	game.get_node("DefenseView").render(value)
	game.get_node("DefenseView/BattlePanels/Pause").hide()
	game.get_node("DefenseAudio").update(value, lab.audio_events)
	lab.audio_events.clear()
	overlay.geometry = Inspector.geometry(lab.world, lab.selected_id)
	overlay.selected = lab.selected_id
	overlay.visible = value.phase == "playing"
	overlay.queue_redraw()
	ui_credit += delta
	if ui_credit >= 0.2:
		ui_credit = 0
		refresh()

func refresh() -> void:
	if panel == null: return
	%Play.text = "继续" if lab.world.paused else "暂停"
	%Timeline.text = "%.3f 秒  ·  %d 单位  ·  %d 弹体  ·  %d 击杀" % [lab.world.time_ms / 1000.0, lab.world.units.size(), lab.world.missiles.size(), lab.world.kills]
	%Mode.text = ("合法构筑" if lab.recipe.legal_terms else "自由配置 · 非正式合法构筑") + ("  /  不死或无敌辅助已开启" if Inspector.roster(lab.world).any(func(u): return u.survival != "normal") else "")
	panel.render()

func fit_battle() -> void:
	var available: Vector2 = %BattleFrame.size
	var ratio = minf(available.x / 960.0, available.y / 1920.0)
	%ViewportContainer.scale = Vector2.ONE * ratio
	%ViewportContainer.position = (available - Vector2(960, 1920) * ratio) / 2

func on_field(point: Vector2, id: int) -> void:
	%PosX.value = roundf(point.x)
	%PosY.value = roundf(point.y)
	if %Place.button_pressed: panel.add_monsters()
	elif id != 0: dispatch("select", {"id": id})

func open_file(mode: String) -> void:
	file_mode = mode
	%FileDialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode in ["config_save", "replay_save", "report"] else FileDialog.FILE_MODE_OPEN_FILE
	%FileDialog.current_file = "战斗测试.json" if mode != "report" else "测试记录.json"
	%FileDialog.popup_centered_ratio(0.8)

func file_selected(path: String) -> void:
	if file_mode in ["config_load", "replay"]:
		load_path(path, file_mode == "replay")
		return
	var value: Dictionary = lab.document()
	if file_mode == "config_save":
		value.config = lab.recipe.duplicate(true)
		value.commands = []
		value.truncated = false
	value["runtime_fingerprint"] = runtime_fingerprint
	if file_mode == "report":
		value["result"] = lab.state()
		value["trace"] = lab.world.trace.duplicate(true)
		value["trace_dropped"] = lab.world.trace_dropped
		value["peak_step_us"] = lab.world.peak_step_us
	show_result(Files.write_json(path, value), "已保存：" + path)

func load_path(path: String, replay: bool) -> void:
	var result = Files.read_json(path)
	if result.has("error"):
		show_result(result.error, "")
		return
	var value: Dictionary = result.value
	if replay and value.get("runtime_fingerprint", "") != runtime_fingerprint:
		show_result("运行代码已变化，请仅加载配置后重新验证", "")
		return
	var error: String = lab.replay(value) if replay else lab.load_config(value.get("config", value))
	game.session = lab.world
	if error.is_empty(): panel.reset_view()
	clock_credit = 0
	show_result(error, "已重放操作" if replay else "已载入配置，战斗处于暂停状态")
	refresh()

func _exit_tree() -> void:
	if game != null: game.session = null
	if lab != null: lab.dispose()
	if panel != null: panel.app = null
