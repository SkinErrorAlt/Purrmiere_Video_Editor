shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform int strings = 96;
uniform float camera = 1.0;
uniform float gloss = 0.6;
uniform vec4 behind : source_color = vec4(0.04, 0.035, 0.03, 1.0);

vec2 swing_of(sampler2D sw, int s, float idx) {
	return fp_unpack2(texelFetch(sw, ivec2(s, max(int(idx) + 1, 0)), 0), 0.25);
}

void fragment() {
	vec2 sz = vec2(textureSize(effect_tex, 0));
	float asp = sz.x / sz.y;
	float n = float(max(strings, 4));
	float pitch_x = 1.0 / n;
	float pitch_y = pitch_x * asp * 1.1547;
	float r = pitch_y * 0.5;
	vec4 src = texture(effect_tex, UV);
	float best = 1e9;
	vec3 col = vec3(0.0);
	bool hit = false;
	float shadow = 0.0;
	int s0 = int(floor(UV.x / pitch_x));
	for (int k = -5; k <= 5; k++) {
		int s = s0 + k;
		if (s < 0 || float(s) >= n) {
			continue;
		}
		float xs = (float(s) + 0.5) * pitch_x;
		float stagger = (s % 2 == 0) ? 0.0 : 0.5;
		float bi = floor(UV.y / pitch_y - stagger);
		for (int b = -1; b <= 1; b++) {
			float idx = bi + float(b);
			float yc = (idx + 0.5 + stagger) * pitch_y;
			if (yc < -pitch_y || yc > 1.0 + pitch_y) {
				continue;
			}
			vec2 swb = swing_of(TEXTURE, s, idx);
			vec2 c = vec2(xs + swb.x, yc + swb.y);
			vec2 d = (UV - c) * vec2(asp, 1.0) / (r * 1.0);
			float dd = dot(d, d);
			vec2 ds = (UV - c - vec2(0.004, 0.006)) * vec2(asp, 1.0) / r;
			shadow = max(shadow, 1.0 - smoothstep(0.6, 1.3, length(ds)));
			if (dd < 1.0 && dd < best) {
				best = dd;
				hit = true;
				vec2 rest = vec2(xs, yc);
				vec3 nrm = vec3(d, sqrt(max(1.0 - dd, 0.0)));
				vec2 inner = rest + nrm.xy * vec2(1.0 / asp, 1.0) * r * 0.35;
				vec3 c0 = texture(effect_tex, clamp(inner, vec2(0.0), vec2(1.0))).rgb;
				float shade = 0.55 + 0.45 * nrm.z + 0.12 * dot(nrm.xy, vec2(-0.6, -0.8));
				vec3 bc = c0 * mix(1.0, shade, 0.9);
				vec3 hv = normalize(vec3(-0.45, -0.6, 1.0) + vec3(0.0, 0.0, 1.0));
				float spec = pow(max(dot(nrm, hv), 0.0), 40.0);
				bc += vec3(spec) * gloss * 0.8;
				bc = mix(bc, bc * 0.6, smoothstep(0.75, 1.0, dd));
				col = bc;
			}
		}
	}
	if (!hit) {
		vec3 room = texture(effect_tex, UV).rgb * 0.18 + behind.rgb;
		col = room * (1.0 - 0.7 * shadow);
		float sx = UV.x / pitch_x - 0.5;
		float fx = abs(sx - round(sx)) * pitch_x * sz.x;
		col = mix(col, vec3(0.25), 0.0 * smoothstep(1.0, 0.0, fx));
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
}
