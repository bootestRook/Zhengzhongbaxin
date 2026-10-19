shader_type canvas_item;

uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 uv = clamp(UV, atlas_region.xy, atlas_region.xy + atlas_region.zw);
	vec4 color = texture(TEXTURE, uv) * COLOR;
	vec2 local_uv = (UV - atlas_region.xy) / atlas_region.zw;
	float distance_from_center = length(local_uv - vec2(0.5));
	float alpha = 1.0 - smoothstep(0.47, 0.5, distance_from_center);
	if (distance_from_center > 0.43) {
		color.rgb = mix(color.rgb, vec3(0.12, 0.11, 0.09), smoothstep(0.43, 0.47, distance_from_center));
	}
	color.a *= alpha;
	COLOR = color;
}
