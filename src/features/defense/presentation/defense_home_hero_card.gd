extends Button

var hero_id: int
var unlocked: bool

func configure(hero: Dictionary, is_unlocked: bool, atlas: DefenseAtlas) -> void:
	hero_id = int(hero.id)
	unlocked = is_unlocked
	$Name.text = hero.name
	$Profession.resource_key = hero.tags[1].res
	$RaceIcon.resource_key = hero.tags[0].res
	$Race.text = hero.tags[0].title
	tooltip_text = hero.name if unlocked else hero.name + " · 还未解锁"
	var portrait_key := "gameIcon:heroHead%d_new" % hero_id
	if not atlas.sprites.has(portrait_key):
		portrait_key = atlas.frame(hero.res + "_idle", 0)
	$Portrait.resource_key = portrait_key
	for sprite in find_children("*", "TextureRect"):
		sprite.configure(atlas)
	# Head portraits and actor frames have different transparent source margins.
	# Fit the visible image, retaining the atlas page and region by name.
	var portrait: AtlasTexture = $Portrait.texture.duplicate()
	portrait.margin = Rect2()
	$Portrait.texture = portrait
	$Portrait.material.set_shader_parameter("locked", not unlocked)
	$RaceIcon.material.set_shader_parameter("locked", not unlocked)
	$Lock.visible = not unlocked
	$LockedShade.visible = not unlocked
	button_down.connect(func(): modulate = Color(0.76, 0.76, 0.76))
	button_up.connect(func(): modulate = Color.WHITE)
	mouse_exited.connect(func(): modulate = Color.WHITE)

func set_selected(value: bool) -> void:
	$Selected.visible = value
