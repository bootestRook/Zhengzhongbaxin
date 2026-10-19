shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.98, 0.96, 0.89, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.86, 0.83, 0.75, 1.0);

void fragment() {
	float diagonal = mod((UV.x + UV.y) * 6.0, 1.0);
	float stripe = smoothstep(0.40, 0.48, diagonal) * (1.0 - smoothstep(0.70, 0.78, diagonal));
	COLOR = mix(base_color, stripe_color, stripe * 0.72);
}
