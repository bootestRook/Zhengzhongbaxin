extends Button

var hero_id: int = 0

func configure(hero: Dictionary, atlas: DefenseAtlas) -> void:
	hero_id = int(hero.id)
	tooltip_text = hero.name
	$Icon.resource_key = "gameIcon:heroHead%d_new" % int(hero.template)
	$Icon.configure(atlas)
	var portrait: AtlasTexture = $Icon.texture.duplicate()
	portrait.margin = Rect2()
	$Icon.texture = portrait
