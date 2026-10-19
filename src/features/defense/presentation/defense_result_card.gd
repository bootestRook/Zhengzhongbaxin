class_name DefenseResultCard
extends Control

signal details_requested(hero: Dictionary)

var atlas: DefenseAtlas
var hero: Dictionary = {}
var totals: Dictionary = {}
var reveal: float = 0.0
var elapsed: int = 0
var extent: Vector2

func _ready() -> void:
	$Info.pressed.connect(func(): details_requested.emit(hero))

func configure(resources: DefenseAtlas, value: Dictionary, sums: Dictionary, mvp: bool) -> void:
	atlas = resources
	hero = value
	totals = sums
	extent = Vector2.ZERO
	for frame in atlas.animations[hero.res + "_idle"].frames:
		var rect: Array = atlas.sprites[frame.sprite].rect
		extent = extent.max(Vector2(rect[2], rect[3]))
	$MVP.visible = mvp
	$MVP.configure(atlas)
	$Info/Icon.configure(atlas)
	$Info.tooltip_text = "查看%s本局属性与技能" % hero.name
	queue_redraw()

func count_up(value: float) -> void:
	reveal = value
	for pair in [["Damage", "damage"], ["Taken", "taken"], ["Heal", "heal"]]:
		var amount: float = hero.stats[pair[1]] * reveal
		get_node(pair[0]).text = compact(amount)
	queue_redraw()

static func compact(value: float) -> String:
	return "%.2fk" % (value / 1000) if value >= 1000 else str(roundi(value))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += roundi(delta * 1000)
	queue_redraw()

func _draw() -> void:
	if atlas == null or hero.is_empty():
		return
	atlas.picture(self, "battle:DPSBG", Rect2(Vector2.ZERO, size))
	atlas.picture(self, "map:choice3_inner", Rect2(10, 11, size.x - 20, 183))
	draw_set_transform(Vector2(size.x / 2, 185), 0, Vector2(1, 0.2))
	draw_circle(Vector2.ZERO, 54, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var key: String = atlas.frame(hero.res + "_idle", elapsed)
	var r: Array = atlas.sprites[key].rect
	var ratio: float = minf((size.x - 60) / extent.x, 126 / extent.y)
	var visible_size := Vector2(r[2], r[3]) * ratio
	atlas.picture(self, key, Rect2(Vector2((size.x - visible_size.x) / 2, 185 - visible_size.y), visible_size))
	var names = ["damage", "taken", "heal"]
	var colors = [Color("ce4d42"), Color("59b8e9"), Color("70cc62")]
	for i in range(3):
		var fraction = float(hero.stats[names[i]]) / maxf(1, float(totals[names[i]]))
		draw_rect(Rect2(32, 197 + i * 33, (size.x - 44) * fraction * reveal, 21), colors[i])
