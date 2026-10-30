shader_type canvas_item;
void fragment() {
	float left_shade = mix(0.72, 0.10, smoothstep(0.05, 0.72, UV.x));
	float footer = smoothstep(0.70, 1.0, UV.y) * 0.24;
	COLOR = vec4(vec3(0.035, 0.075, 0.14), min(left_shade + footer, 0.85));
}
