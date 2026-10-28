shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.25, 0.30, 1.0);
uniform float outline_width_texels : hint_range(1.0, 48.0, 0.5) = 2.0;
uniform float outline_strength : hint_range(0.0, 1.0, 0.05) = 0.95;

void fragment() {
	vec4 base = COLOR;
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width_texels;

	float min_alpha = 1.0;
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2( offset.x, 0.0)).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(0.0,  offset.y)).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(0.0, -offset.y)).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2( offset.x,  offset.y) * 0.7071).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-offset.x,  offset.y) * 0.7071).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2( offset.x, -offset.y) * 0.7071).a);
	min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-offset.x, -offset.y) * 0.7071).a);

	float edge = clamp((base.a - min_alpha) * 4.0, 0.0, 1.0);
	base.rgb = mix(base.rgb, outline_color.rgb, edge * outline_strength);
	COLOR = base;
}
