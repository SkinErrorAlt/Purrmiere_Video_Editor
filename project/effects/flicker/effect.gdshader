shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.1, 60.0) = 12.0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform float colour_flicker : hint_range(0.0, 1.0) = 0.1;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float wobble(float t, float salt, vec2 so) {
	float i = floor(t);
	float f = t - i;
	float s = clamp(smoothness, 0.0, 1.0);
	float w = s > 0.001 ? smoothstep(1.0 - s, 1.0, f) : 0.0;
	float h0 = hash12(vec2(i, salt) + so);
	float h1 = hash12(vec2(i + 1.0, salt) + so);
	return mix(h0, h1, w);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 so = seed_offset(seed);
	float t = max(clip_time, 0.0) * clamp(speed, 0.1, 60.0);
	float n = wobble(t, 1.0, so) * 0.7 + wobble(t * 2.37 + 0.5, 2.0, so) * 0.3;
	float dip = wobble(t * 0.5, 3.0, so);
	float stops = (n - 0.55) * 2.0 * amount;
	stops -= smoothstep(0.8, 1.0, dip) * amount * 1.2;
	float lift = (wobble(t * 1.3, 4.0, so) - 0.5) * amount * 0.06;
	vec3 tint = vec3(wobble(t, 5.0, so), wobble(t, 6.0, so), wobble(t, 7.0, so)) - 0.5;
	vec3 gain = exp2(vec3(stops) + tint * colour_flicker * 0.6);
	rgb = rgb * gain + lift;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
