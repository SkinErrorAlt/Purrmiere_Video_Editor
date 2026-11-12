shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/slime_mould/sim.gdshaderinc"

uniform sampler2D s_tex : filter_nearest, repeat_disable;
uniform float clip_time = 0.0;
uniform float start_time : hint_range(0.0, 30.0) = 0.0;

const int FOODS = 24;
const int STEPS = 64;
const float T_RANGE = 120.0;

vec2 walk(sampler2D tex, int s, int i) {
	vec4 c = texelFetch(tex, ivec2(s, i), 0);
	return vec2(sim_unpack(c.rg), sim_unpack(c.ba));
}

void fragment() {
	ivec2 wsz = textureSize(TEXTURE, 0);
	vec2 tsz = vec2(textureSize(s_tex, 0));
	float asp = tsz.x / max(tsz.y, 1.0);
	vec2 q = vec2(UV.x * asp, UV.y);
	float front = clip_time - start_time;
	float dmin = 1.0;
	float near = 0.0;
	float grow = 0.0;
	float along = 0.0;
	int steps = min(STEPS, wsz.x);
	for (int i = 0; i < FOODS; i++) {
		if (i >= wsz.y) {
			break;
		}
		vec2 f = walk(TEXTURE, 0, i);
		if (f.x > 0.999 && f.y > 0.999) {
			continue;
		}
		float tfood = sim_field(s_tex, f) * T_RANGE;
		float g = front - tfood;
		if (g <= 0.0) {
			continue;
		}
		float gr = smoothstep(0.0, 3.0, g);
		vec2 a = vec2(f.x * asp, f.y);
		float di = 1.0;
		for (int s = 1; s < STEPS; s++) {
			if (s >= steps) {
				break;
			}
			vec2 w = walk(TEXTURE, s, i);
			vec2 b = vec2(w.x * asp, w.y);
			vec2 ab = b - a;
			float h = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
			di = min(di, length(q - a - ab * h));
			a = b;
		}
		near += (1.0 - smoothstep(0.004, 0.02, di)) * gr;
		if (di < dmin) {
			dmin = di;
			grow = gr;
		}
	}
	along = sim_field(s_tex, UV);
	COLOR = vec4(clamp(dmin * 20.0, 0.0, 1.0), clamp(near / 12.0, 0.0, 1.0), grow, along);
}
