class_name DefenseChoiceCard
extends Button

# 招募正文只显示“招募英雄名”，强化正文使用词条原文；招募额外显示种族与职业小字。
# 规则结果由 Intent 决定，入场与确认动效只属于表现层。
signal details_requested

var atlas: DefenseAtlas
var hero: Dictionary = {}
var option: Dictionary = {}
var actor_key: String = ""
var hero_choice: bool = false
var elapsed: int = 0
var press_motion: Tween

func _ready() -> void:
	pivot_offset = size / 2
	$Info.pressed.connect(func(): details_requested.emit())
	button_down.connect(func(): press_to(Vector2.ONE * 0.975))
	button_up.connect(func(): press_to(Vector2.ONE))

func _exit_tree() -> void:
	stop_press()

func configure(art: DefenseAtlas, item: Dictionary, definitions, snapshot: Dictionary) -> void:
	atlas = art
	hero_choice = item.kind == "hero"
	actor_key = item.res
	var hero_id: int = int(item.id) if hero_choice else 0
	for owned in snapshot.heroes:
		if int(owned.id) == int(item.owner):
			hero_id = int(owned.template)
	hero = definitions.record("heroes", hero_id)
	assert(not hero.is_empty(), "choice must belong to a hero")
	option = definitions.record("options", int(hero.initial_options[0] if hero_choice else item.id))
	$Title.text = hero.name
	var width: float = atlas.font.get_string_size(option.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	$TermName.text = option.title
	$TermName.add_theme_font_size_override("font_size", mini(40, floori(40 * ($TermName.size.x - 10) / maxf(1, width))))
	$Level.text = "招募" if hero_choice else "强化"
	$Description/Text.text = item.description
	$Description.scroll_vertical = 0
	$Traits.visible = hero_choice
	$Traits.text = "%s · %s" % [hero.tags[0].title, hero.tags[1].title] if hero_choice else ""
	$Info.visible = true
	$Info.tooltip_text = "查看英雄属性"
	queue_redraw()

func press_to(target: Vector2) -> void:
	if press_motion != null:
		press_motion.kill()
	press_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	press_motion.tween_property(self, "scale", target, 0.09)

func stop_press() -> void:
	if press_motion != null:
		press_motion.kill()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += roundi(delta * 1000)
	queue_redraw()

func _draw() -> void:
	if atlas == null:
		return
	atlas.picture(self, "map:skillCard2", Rect2(Vector2.ZERO, size), Color(1.024, 1.004, 1.004))
	atlas.picture(self, "map:choice3_inner", Rect2(28, 24, 240, 244))
	if not hero.is_empty():
		draw_ellipse(Vector2(146, 237), 80, 13, Color(0, 0, 0, 0.25))
		var frame: Dictionary = atlas.sprites[atlas.frame(actor_key + "_idle", 0)]
		var rect: Array = frame.rect
		var scale_value: float = minf(1.8, minf(268.0 / float(rect[2]), 200.0 / float(rect[3])))
		var anchor = Vector2(float(frame.offset[0]) + float(rect[2]) / 2, float(frame.offset[1]) + float(rect[3])) / Vector2(frame.size[0], frame.size[1])
		atlas.draw(self, actor_key + "_idle", Vector2(146, 241), Vector2(-scale_value, scale_value), elapsed, anchor)
	atlas.picture(self, "map:heroNameBg", Rect2(28, 296, 240, 43), Color(1.024, 1.01, 1.024))
	atlas.picture(self, "map:heroNameBg", $TermName.get_rect(), Color(1.024, 1.01, 1.024))
	if not hero.is_empty():
		atlas.picture(self, "map:buffCard_hero_Info", Rect2(221, 14, 52, 51))
	if has_focus():
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Color(1, 0.82, 0.25), false, 4)
