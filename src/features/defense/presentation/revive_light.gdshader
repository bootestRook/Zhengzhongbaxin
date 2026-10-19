shader_type canvas_item;
render_mode unshaded;

void fragment() {
	COLOR.rgb = COLOR.bgr;
}
