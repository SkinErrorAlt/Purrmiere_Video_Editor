shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform float threshold : hint_range(0.0, 0.9) = 0.02;
uniform float gamma : hint_range(0.2, 5.0) = 1.0;
uniform float boost : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 src = mode == 1 ? vec3(1.0) - rgb : rgb;
	float peak = max(src.r, max(src.g, src.b));
	vec3 pure = peak > 0.0001 ? src / peak : vec3(0.0);
	float key = clamp((peak - threshold) / max(1.0 - threshold, 0.0001), 0.0, 1.0);
	key = pow(key, max(gamma, 0.01));
	float keep = 1.0 - clamp(boost, 0.0, 1.0) * 0.9;
	key = key / max(key + (1.0 - key) * keep, 0.0001);
	vec3 col = mode == 1 ? vec3(1.0) - pure : pure;
	float oa = clamp(a * key, 0.0, 1.0);
	COLOR = vec4(clamp(col, 0.0, 1.0) * oa, oa);
}
