shader_type canvas_item;
render_mode unshaded;

void fragment() {
    float width = mix(0.20, 0.55, smoothstep(0.0, 0.58, UV.y));
    float beam = exp(-pow((UV.x - 0.5) / width, 2.0) * 3.5);
    float ends = smoothstep(0.0, 0.09, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
    COLOR = vec4(vec3(1.0), beam * ends * 0.58) * COLOR;
}
