shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float span = 1.0;
uniform bool camera = true;
uniform float refraction = 14.0;
uniform float detail = 0.5;
uniform float rim = 0.5;
uniform float shimmer = 0.4;
uniform float visibility = 0.12;
uniform vec4 tint : source_color = vec4(0.80, 0.92, 1.0, 1.0);

const int SAMPLES = 6;

float lum(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec4 plate(vec2 uv, vec2 cam, float step_f) {
	vec4 cs[SAMPLES];
	float ls[SAMPLES];
	vec4 now_c = texture(effect_tex, uv);
	for (int i = 0; i < SAMPLES; i++) {
		float age = step_f * float(i + 1);
		vec2 u2 = clamp(uv - cam * age, vec2(0.0), vec2(1.0));
		vec4 c = history_between(age, u2, now_c);
		cs[i] = c;
		ls[i] = lum(c);
	}
	int best = 0;
	int best_score = 99;
	for (int i = 0; i < SAMPLES; i++) {
		int below = 0;
		int above = 0;
		for (int j = 0; j < SAMPLES; j++) {
			below += ls[j] < ls[i] ? 1 : 0;
			above += ls[j] > ls[i] ? 1 : 0;
		}
		int score = abs(below - above);
		if (score < best_score) {
			best_score = score;
			best = i;
		}
	}
	vec4 r = cs[0];
	for (int i = 1; i < SAMPLES; i++) {
		if (i == best) {
			r = cs[i];
		}
	}
	return r;
}

float mask_at(sampler2D m, vec2 uv) {
	return texture(m, uv).r;
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 now_c = texture(effect_tex, UV);
	float m = mask_at(TEXTURE, UV);
	if (m < 0.002) {
		COLOR = now_c;
	} else {
		float fps = max(history_fps, 1.0);
		float step_f = max(span * fps / float(SAMPLES), 0.5);
		vec2 cam = camera ? kit_global(global_tex, UV) / out_size : vec2(0.0);
		vec2 h = vec2(3.0 * ps) / out_size;
		vec2 grad = vec2(mask_at(TEXTURE, UV + vec2(h.x, 0.0)) - mask_at(TEXTURE, UV - vec2(h.x, 0.0)),
			mask_at(TEXTURE, UV + vec2(0.0, h.y)) - mask_at(TEXTURE, UV - vec2(0.0, h.y)));
		float gl = length(grad);
		vec2 hp = vec2(2.0 * ps) / out_size;
		vec2 lg = vec2(lum(texture(effect_tex, UV + vec2(hp.x, 0.0))) - lum(texture(effect_tex, UV - vec2(hp.x, 0.0))),
			lum(texture(effect_tex, UV + vec2(0.0, hp.y))) - lum(texture(effect_tex, UV - vec2(0.0, hp.y))));
		vec2 wob = vec2(sin(UV.y * 90.0 / max(ps, 0.2) * 0.3 + time * 3.1), cos(UV.x * 80.0 / max(ps, 0.2) * 0.3 - time * 2.7));
		vec2 off_px = -grad * refraction * 2.2 + lg * detail * refraction * 1.6 + wob * shimmer * 1.5 * m;
		vec2 off = off_px * ps / out_size;
		vec4 r = plate(clamp(UV + off * 1.08, vec2(0.0), vec2(1.0)), cam, step_f);
		vec4 g = plate(clamp(UV + off, vec2(0.0), vec2(1.0)), cam, step_f);
		vec4 b = plate(clamp(UV + off * 0.92, vec2(0.0), vec2(1.0)), cam, step_f);
		vec3 bg = vec3(r.r, g.g, b.b);
		float a = max(now_c.a, 0.0001);
		vec3 bgu = bg / max(g.a, 0.0001);
		float edge = clamp(gl * 3.0, 0.0, 1.0);
		vec3 glass = bgu * mix(vec3(1.0), tint.rgb, 0.35);
		glass += tint.rgb * edge * rim * 0.55;
		vec3 nowu = now_c.rgb / a;
		glass = mix(glass, nowu, visibility);
		vec3 outc = mix(nowu, glass, smoothstep(0.0, 0.85, m));
		COLOR = vec4(clamp(outc, 0.0, 1.0) * now_c.a, now_c.a);
	}
}
