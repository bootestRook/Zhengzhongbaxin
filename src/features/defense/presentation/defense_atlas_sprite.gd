class_name DefenseAtlasSprite
extends TextureRect

@export var resource_key: String = ""

func configure(atlas: DefenseAtlas) -> void:
	var sprite: AtlasTexture = atlas.texture(resource_key)
	texture = sprite
	if material is ShaderMaterial:
		var page_size: Vector2 = sprite.atlas.get_size()
		var r: Rect2 = sprite.region
		material.set_shader_parameter("atlas_region", Vector4(r.position.x / page_size.x,
			r.position.y / page_size.y, r.size.x / page_size.x, r.size.y / page_size.y))
