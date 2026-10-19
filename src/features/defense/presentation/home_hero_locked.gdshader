shader_type canvas_item;

uniform bool locked = false;
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 uv = clamp(UV, atlas_region.xy, atlas_region.xy + atlas_region.zw);
	vec4 color = texture(TEXTURE, uv) * COLOR;
	if (locked) {
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		color.rgb = vec3(gray * 0.54);
	}
	COLOR = color;
}
