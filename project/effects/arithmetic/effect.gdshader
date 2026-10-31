shader_type canvas_item;
render_mode blend_disabled;

uniform int op : hint_range(0, 7) = 0;
uniform vec4 operand : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform bool clip_result = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 b = operand.rgb;
	vec3 o = rgb;
	if (op == 0) { o = rgb + b; }
	else if (op == 1) { o = rgb - b; }
	else if (op == 2) { o = rgb * b; }
	else if (op == 3) { o = abs(rgb - b); }
	else if (op == 4) { o = 1.0 - (1.0 - rgb) * (1.0 - b); }
	else if (op == 5) { o = max(rgb, b); }
	else if (op == 6) { o = min(rgb, b); }
	else { o = rgb + b - 2.0 * rgb * b; }
	rgb = clip_result ? clamp(o, 0.0, 1.0) : o;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
