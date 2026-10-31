shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int source : hint_range(0, 4) = 0;
uniform sampler2D gradient_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float scale : hint_range(0.1, 10.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float feather : hint_range(0.0, 0.5) = 0.1;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	vec2 q = p;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) { break; }
		sum += value_noise(q) * amp;
		total += amp;
		q = q * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return total > 0.0 ? sum / total : 0.0;
}

float wipe_keep(float t, float prog, float soft_in) {
	float s = max(soft_in, 0.0001);
	float e = clamp(prog, 0.0, 1.0) * (1.0 + 2.0 * s) - s;
	return smoothstep(e - s, e + s, t);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	vec2 pos = (UV - 0.5) * vec2(asp, 1.0);
	float t = 0.0;
	bool through = false;
	if (source == 1) {
		float rad = radians(angle);
		vec2 dir = vec2(cos(rad), sin(rad));
		float span = max(asp * abs(dir.x) + abs(dir.y), 0.0001);
		t = dot(pos, dir) / span + 0.5;
	} else if (source == 2) {
		vec2 cen = (centre - 0.5) * vec2(asp, 1.0);
		vec2 h = vec2(0.5 * asp, 0.5);
		float far_c = max(max(length(vec2(-h.x, -h.y) - cen), length(vec2(h.x, -h.y) - cen)), max(length(vec2(-h.x, h.y) - cen), length(h - cen)));
		t = length(pos - cen) / max(far_c, 0.0001);
	} else if (source == 3) {
		vec2 so = hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 400.0;
		float n = fbm(UV * vec2(asp, 1.0) * (4.0 / max(scale, 0.01)) + so, 5);
		t = 1.0 / (1.0 + exp(-15.0 * (n - 0.5)));
	} else if (source == 4) {
		vec4 g = texture(gradient_picture, UV);
		if (g.a < 0.0001) {
			through = true;
		} else {
			t = dot(clamp(g.rgb / g.a, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722));
		}
	} else {
		t = dot(clamp(rgb, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722));
	}
	t = clamp(t, 0.0, 1.0);
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	if (through) { keep = 1.0; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
