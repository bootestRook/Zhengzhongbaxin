shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV, 2.4).rgb * 0.24, 1.0);
}
