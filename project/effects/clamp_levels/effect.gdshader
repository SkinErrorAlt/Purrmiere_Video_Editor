shader_type canvas_item;
render_mode blend_disabled;

uniform float floor_v : hint_range(0.0, 1.0) = 0.0;
uniform float ceiling_v : hint_range(0.0, 1.0) = 1.0;
uniform float soft : hint_range(0.0, 1.0) = 0.0;
uniform bool per_channel = true;

float squash(float x, float lo, float hi, float s) {
	float span = max(hi - lo, 0.0001);
	float t = (x - lo) / span;
	float hard = clamp(t, 0.0, 1.0);
	float rolled = t / (1.0 + max(t - 1.0, 0.0) * 4.0);
	rolled = rolled < 0.0 ? rolled / (1.0 - rolled * 4.0) : rolled;
	return lo + mix(hard, clamp(rolled, 0.0, 1.0), s) * span;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float lo = min(floor_v, ceiling_v);
	float hi = max(floor_v, ceiling_v);
	if (per_channel) {
		rgb = vec3(squash(rgb.r, lo, hi, soft), squash(rgb.g, lo, hi, soft), squash(rgb.b, lo, hi, soft));
	} else {
		float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float want = squash(luma, lo, hi, soft);
		rgb *= luma > 0.0001 ? want / luma : 0.0;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
