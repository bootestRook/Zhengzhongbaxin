shader_type canvas_item;
uniform vec4 atlas_region;

void fragment() {
	vec4 light = texture(TEXTURE, UV) * COLOR;
	vec2 local_uv = (UV - atlas_region.xy) / atlas_region.zw;
	light.a *= mix(0.40, 1.0, smoothstep(0.52, 0.80, local_uv.x));
	COLOR = light;
}
