shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int tiles = 12;
uniform float strength = 1.5;
uniform float gap = 0.5;
uniform float turn = 0.5;
uniform vec4 water : source_color = vec4(0.02, 0.05, 0.07, 1.0);
uniform int seed = 3;

vec4 h4(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099) + float(seed) * 0.0137);
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

void fragment() {
	vec2 sz = vec2(textureSize(effect_tex, 0));
	float asp = sz.x / sz.y;
	float n = float(max(tiles, 1));
	vec2 grid = vec2(n, max(1.0, round(n / asp)));
	vec2 cell = 1.0 / grid;
	vec4 src = texture(effect_tex, UV);
	bool still = true;
	for (int k = 0; k < 16; k++) {
		if (fp_x(TEXTURE, k) != vec2(0.0)) {
			still = false;
		}
	}
	if (still || strength == 0.0) {
		COLOR = src;
	} else {
		vec2 g = UV * grid;
		vec2 gi = floor(g);
		float best_h = -1.0;
		vec2 best_uv = UV;
		vec2 best_local = vec2(0.0);
		float best_tilt = 0.0;
		vec2 best_tdir = vec2(0.0);
		float best_agit = 0.0;
		float shadow = 0.0;
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				vec2 t = gi + vec2(float(i), float(j));
				if (t.x < 0.0 || t.y < 0.0 || t.x >= grid.x || t.y >= grid.y) {
					continue;
				}
				vec4 h = h4(t + 17.0);
				int k = int(h.x * 15.999);
				vec2 x = fp_x(TEXTURE, k);
				vec2 v = fp_v(TEXTURE, k);
				float an = (h.y - 0.5) * 0.9;
				mat2 jr = mat2(vec2(cos(an), sin(an)), vec2(-sin(an), cos(an)));
				vec2 d = jr * x * strength * (0.7 + 0.6 * h.z);
				float agit = clamp(length(x * strength) / 0.03, 0.0, 1.0);
				float th = turn * (h.w - 0.5) * 2.0 * clamp(length(x * strength) * 6.0, 0.0, 0.5);
				float sc = 1.0 - gap * 0.14 * agit * (0.6 + 0.8 * h.z);
				vec2 centre = (t + 0.5) * cell + d;
				vec2 q = (UV - centre) * vec2(asp, 1.0);
				mat2 r = mat2(vec2(cos(th), -sin(th)), vec2(sin(th), cos(th)));
				vec2 l = r * q / sc / vec2(asp, 1.0);
				vec2 half_ = cell * 0.5;
				vec2 e = abs(l) - half_;
				vec2 ls = r * (q - vec2(0.006, 0.009) * agit) / sc / vec2(asp, 1.0);
				vec2 es = abs(ls) - half_;
				shadow = max(shadow, 1.0 - smoothstep(-0.002, 0.012, max(es.x, es.y)));
				if (e.x <= 0.0 && e.y <= 0.0) {
					float ht = h.z + 0.001 * h.w;
					if (ht > best_h) {
						best_h = ht;
						best_uv = (t + 0.5) * cell + l;
						best_local = l / half_;
						best_tdir = v * strength;
						best_agit = agit;
					}
				}
			}
		}
		vec3 col;
		if (best_h >= 0.0) {
			col = texture(effect_tex, clamp(best_uv, vec2(0.0), vec2(1.0))).rgb;
			float lean = clamp(dot(best_local, normalize(best_tdir + vec2(1e-5))) * length(best_tdir) * 3.0, -0.35, 0.35);
			col *= 1.0 + lean;
			vec2 el = 1.0 - abs(best_local);
			float rim = 1.0 - smoothstep(0.0, 0.05, min(el.x, el.y));
			col = mix(col, col * 0.55, rim * best_agit * 0.8);
			float top = 1.0 - smoothstep(0.0, 0.03, el.y) ;
			col += vec3(0.08) * top * best_agit * step(best_local.y, 0.0);
		} else {
			vec2 wuv = vec2(UV.x, UV.y) + vec2(sin(UV.y * 60.0), cos(UV.x * 47.0)) * 0.004;
			vec3 refl = vec3(0.0);
			for (int i = 0; i < 5; i++) {
				refl += texture(effect_tex, clamp(wuv + vec2(0.0, float(i - 2) * 0.006), vec2(0.0), vec2(1.0))).rgb;
			}
			refl /= 5.0;
			col = water.rgb + refl * refl * 0.22;
			col *= 1.0 - 0.6 * shadow;
		}
		COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
	}
}
