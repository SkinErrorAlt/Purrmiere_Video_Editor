shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float scale : hint_range(0.1, 10.0) = 1.0;
uniform float burn_width : hint_range(0.0, 0.5) = 0.08;
uniform vec4 burn_colour : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 char_colour : source_color = vec4(0.07, 0.04, 0.02, 1.0);
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float feather : hint_range(0.0, 0.5) = 0.01;
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 so = hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 400.0;
	float n = fbm(UV * vec2(sz.x / sz.y, 1.0) * (3.0 / max(scale, 0.01)) + so, 6);
	float t = 1.0 / (1.0 + exp(-15.0 * (n - 0.5)));
	float w = clamp(burn_width, 0.0, 1.0);
	float s = max(feather, 0.0001);
	float pr = clamp(progress, 0.0, 1.0);
	float d;
	if (invert) {
		float e = pr * (1.0 + w + 2.0 * s) - s;
		d = e - t;
	} else {
		float e = pr * (1.0 + w + 2.0 * s) - (w + s);
		d = t - e;
	}
	float keep = smoothstep(-s, s, d);
	float x = d / max(w, 0.0001);
	float heat = 1.0 - smoothstep(0.0, 0.4, x);
	float charred = 1.0 - smoothstep(0.25, 1.0, x);
	vec3 col = mix(clamp(rgb, 0.0, 1.0), char_colour.rgb, charred * char_colour.a);
	col = mix(col, burn_colour.rgb, heat * burn_colour.a);
	col += burn_colour.rgb * heat * heat * glow * 0.5 * burn_colour.a;
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(col, 0.0, 1.0) * oa, oa);
}
