shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.85;
uniform float linger : hint_range(0.0, 1.0) = 0.6;
uniform vec2 centre = vec2(0.5, 0.78);
uniform float reach : hint_range(0.2, 2.0) = 1.0;
uniform float droplets : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tint : source_color = vec4(0.86, 0.9, 0.95, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

vec3 tent(sampler2D tex, vec2 uv, vec2 px) {
	vec3 s = unpm(texture(tex, uv)) * 4.0;
	s += (unpm(texture(tex, uv + vec2(px.x, 0.0))) + unpm(texture(tex, uv - vec2(px.x, 0.0))) + unpm(texture(tex, uv + vec2(0.0, px.y))) + unpm(texture(tex, uv - vec2(0.0, px.y)))) * 2.0;
	s += unpm(texture(tex, uv + px)) + unpm(texture(tex, uv - px)) + unpm(texture(tex, uv + vec2(px.x, -px.y))) + unpm(texture(tex, uv + vec2(-px.x, px.y)));
	return s / 16.0;
}

void fragment() {
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	vec4 sharp4 = texture(effect_tex, UV);
	float a = sharp4.a;
	vec3 sharp = unpm(sharp4);
	vec3 mid = unpm(texture(mid_tex, UV));
	vec2 hp = 1.0 / max(tex_size, vec2(1.0));
	vec3 heavy = tent(TEXTURE, UV, hp);
	float asp = full.x / full.y;
	vec2 p = vec2(UV.x * asp, UV.y);
	float f = clamp(mix(snd_voice, snd_voice_slow * 1.3, linger), 0.0, 1.0);
	vec2 dc = (UV - centre) * vec2(asp, 1.0);
	float d = length(dc) / max(reach, 0.05);
	float n = snd_fbm(p * 3.2 + vec2(0.0, clip_time * 0.03));
	float n2 = snd_fbm(p * 11.0 + 7.0);
	float breath = f * (1.35 - d * 0.9) + (n2 - 0.5) * 0.12;
	float m = smoothstep(n - 0.12, n + 0.12, breath) * density;
	vec3 base = mix(mid, heavy, smoothstep(0.2, 0.9, m));
	float y = dot(base, LUMA);
	vec3 fogged = mix(base, tint.rgb * (0.55 + 0.45 * y) + base * 0.25, 0.42 * m);
	fogged = mix(vec3(y), fogged, 1.0 - 0.3 * m);
	vec3 rgb = mix(sharp, fogged, smoothstep(0.0, 0.6, m));
	float cell = 28.0 * ps;
	vec2 g = UV * full / cell;
	vec2 gi = floor(g);
	float heavy_fog = smoothstep(0.5, 0.95, m) * droplets * 0.32 * clamp(snd_voice_slow * 1.4, 0.0, 1.0) * smoothstep(0.25, 0.9, UV.y);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cid = gi + vec2(float(i), float(j));
			vec2 rr = snd_hash2(cid * 1.37 + 5.0);
			float born = snd_hash(cid * 2.11 + 1.0);
			if (born > heavy_fog) {
				continue;
			}
			vec2 cpos = cid + 0.2 + rr * 0.6;
			float sz = snd_hash(cid + 9.0);
			float rad = (0.1 + 0.42 * sz * sz) * smoothstep(0.0, 0.12, heavy_fog - born);
			vec2 off = g - cpos;
			float dd = length(off) / max(rad, 0.001);
			if (dd < 1.0) {
				vec2 lens = cpos * cell / full - off * cell / full * 2.2;
				vec3 inside = unpm(texture(effect_tex, clamp(lens, vec2(0.0), vec2(1.0))));
				float rim = smoothstep(0.65, 1.0, dd);
				vec3 drop = inside * (1.0 - 0.45 * rim) + vec3(0.05) * rim;
				float hl = 1.0 - smoothstep(0.0, 0.28, length(off / max(rad, 0.001) - vec2(-0.35, -0.4)));
				drop += vec3(0.9) * hl * 0.6;
				rgb = mix(rgb, drop, 1.0 - smoothstep(0.9, 1.0, dd));
			}
		}
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
