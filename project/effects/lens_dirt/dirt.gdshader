shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.3;
uniform float dirt : hint_range(0.0, 1.0) = 0.75;
uniform float plain_glow : hint_range(0.0, 1.0) = 0.2;
uniform float dirt_size : hint_range(0.3, 3.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform bool show_dirt = false;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 4; i++) {
		s += w * vnoise(p);
		p = p * 2.1 + vec2(3.7, 8.1);
		w *= 0.5;
	}
	return s / 0.9375;
}

float specks(vec2 p, float cells, float chance, float sd, float rimmed) {
	vec2 q = p * cells;
	vec2 id = floor(q);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cid = id + vec2(float(x), float(y));
			vec3 h = hash32(cid + sd);
			if (h.z < chance) {
				vec2 ctr = cid + 0.2 + 0.6 * h.xy;
				float r = 0.08 + 0.4 * fract(h.x * 7.3 + h.y * 3.1);
				float d = length(q - ctr);
				float disc = 1.0 - smoothstep(r * 0.55, r, d);
				float z = (d - r * 0.85) / (r * 0.12);
				float ring = rimmed * exp(-z * z);
				float b = 0.35 + 0.65 * fract(h.z * 13.7);
				best = max(best, (disc * (1.0 - rimmed * 0.55) + ring * 0.6) * b);
			}
		}
	}
	return best;
}

float dirt_at(vec2 uv, float asp) {
	float k = 1.0 / max(dirt_size, 0.05);
	vec2 p = vec2(uv.x * asp, uv.y) * k;
	float sd = float(seed) * 1.713 + 0.37;
	float smudge = smoothstep(0.42, 0.85, fbm(p * 2.2 + sd)) * 0.9;
	float haze = fbm(p * 5.0 - sd) * 0.25;
	float fine = specks(p, 22.0, 0.3, sd, 0.0);
	float discs = specks(p, 5.0, 0.35, sd + 19.0, 1.0) * 0.8;
	vec2 wdir = normalize(vec2(0.8, 0.35) + (hash32(vec2(sd, 1.0)).xy - 0.5));
	float streak_phase = dot(p, wdir) * 90.0 + fbm(p * 3.0 + sd * 2.0) * 9.0;
	float streaks = pow(0.5 + 0.5 * sin(streak_phase), 6.0) * smoothstep(0.5, 0.75, fbm(p * 1.6 + sd * 3.0 + 7.0));
	return clamp(smudge + haze * smudge + fine + discs + streaks * 0.5, 0.0, 1.6);
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float asp = full.x / full.y;
	float dt = dirt_at(UV, asp);
	if (show_dirt) {
		COLOR = vec4(vec3(dt / 1.6), 1.0);
	} else {
		vec4 g = max(texture(TEXTURE, UV), vec4(0.0)) * 0.25;
		float lens = clamp(plain_glow, 0.0, 1.0) + clamp(dirt, 0.0, 1.0) * dt * 3.0;
		vec3 add = g.rgb * tint.rgb * max(intensity, 0.0) * lens;
		float glow_a = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
		float oa = clamp(o.a + glow_a * (1.0 - o.a), 0.0, 1.0);
		vec3 rgb = min(o.rgb + add, vec3(oa));
		COLOR = vec4(max(rgb, vec3(0.0)), oa);
	}
}
