shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_length : hint_range(2.0, 60.0) = 24.0;
uniform float balance : hint_range(0.0, 100.0) = 50.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform vec4 ink : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

float strokes(float along, float across, float len, float spacing, float tone, vec2 so, float gain) {
	float s = across / spacing;
	float lane = floor(s);
	float f = fract(s);
	float dk = 1.0 - tone;
	float pw = 0.12 + 0.3 * dk * dk;
	float prof = 1.0 - smoothstep(pw, pw + 0.16, abs(f - 0.5));
	float off = hash12(vec2(lane, so.x)) * len;
	float u = (along + off) / len;
	float k = floor(u);
	float fs = fract(u);
	float t = fract(lane * 0.6180339 + k * 0.381966 + hash12(vec2(lane, k) + so) * 0.35);
	float reach = mix(0.55 + 0.45 * hash12(vec2(k, lane) + so.yx), 1.05, dk * dk);
	float on = smoothstep(0.0, 0.05, fs) * (1.0 - smoothstep(reach - 0.05, reach, fs));
	return prof * on * smoothstep(tone - 0.03, tone + 0.03, t * gain);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float a = texture(TEXTURE, UV).a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float ang = radians(angle);
	vec2 dir = vec2(cos(ang), -sin(ang));
	float len = max(stroke_length, 2.0);
	vec2 su = dir * len * 0.12 * ps / dims;
	float tone = 0.0;
	for (int i = -2; i <= 2; i++) {
		tone += lum(texture(TEXTURE, UV + su * float(i)));
	}
	tone = smoothstep(0.12, 0.72, tone / 5.0 + (50.0 - balance) / 100.0 * 0.8);
	float along = dot(pix, dir);
	float across = dot(pix, vec2(-dir.y, dir.x));
	float spacing = 1.8;
	float i1 = strokes(along, across, len, spacing, tone, so, 1.0);
	float i2 = strokes(along + len * 0.37, across + spacing * 0.5, len * 0.8, spacing, tone, so + 31.0, 0.55);
	float inked = clamp(max(i1, i2), 0.0, 1.0);
	vec3 outc = mix(paper.rgb, ink.rgb, inked);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
