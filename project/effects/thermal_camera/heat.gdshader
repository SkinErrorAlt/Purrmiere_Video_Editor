shader_type canvas_item;
render_mode blend_disabled;

uniform float body_heat : hint_range(0.0, 1.0) = 0.7;
uniform float sky_cold : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float cb = 0.5 + (-0.1146 * rgb.r - 0.3854 * rgb.g + 0.5 * rgb.b);
	float cr = 0.5 + (0.5 * rgb.r - 0.4542 * rgb.g - 0.0458 * rgb.b);
	float skin = smoothstep(0.035, 0.0, abs(cb - 0.40) - 0.06) * smoothstep(0.035, 0.0, abs(cr - 0.6) - 0.06);
	skin *= smoothstep(0.12, 0.3, y) * (1.0 - smoothstep(0.9, 1.0, y));
	float blue_lead = rgb.b - max(rgb.r, rgb.g * 0.95);
	float sky = smoothstep(-0.02, 0.12, blue_lead) * smoothstep(0.3, 0.6, y);
	float pale = smoothstep(0.7, 0.9, y) * (1.0 - smoothstep(0.03, 0.12, max(max(rgb.r, rgb.g), rgb.b) - min(min(rgb.r, rgb.g), rgb.b)));
	sky = max(sky, pale * 0.6) * (1.0 - smoothstep(0.35, 0.85, UV.y));
	float veg = smoothstep(0.0, 0.12, rgb.g - max(rgb.r, rgb.b) * 1.02) * (1.0 - smoothstep(0.6, 0.9, y));
	float lights = smoothstep(0.9, 0.99, y);
	float heat = 0.42 + 0.13 * y + skin * body_heat * 0.42 - sky * sky_cold * 0.32 - veg * 0.07 + lights * 0.22;
	heat = clamp(heat, 0.0, 1.0);
	COLOR = vec4(heat * a, y * a, heat * heat * a, a);
}
