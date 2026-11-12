shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float rate : hint_range(0.0, 15.0) = 3.0;
uniform float slice : hint_range(0.0, 1.0) = 0.35;
uniform float refresh : hint_range(0.1, 2.0) = 1.4;
uniform float block : hint_range(8.0, 64.0) = 16.0;
uniform float carry : hint_range(0.0, 1.0) = 0.7;
uniform float grey : hint_range(0.0, 1.0) = 0.05;
uniform int seed = 0;
uniform float clip_time = 0.0;
uniform float px_scale = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031 + float(seed) * 0.017);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec3 hash31(float p) {
	vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973) + float(seed) * 0.013);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec4 now = texture(TEXTURE, UV);
	float fps = max(history_fps, 1.0);
	int n = int(floor(max(clip_time, 0.0) * fps + 0.0001));
	float bp = max(block * px_scale, 2.0);
	ivec2 nb = ivec2(ceil(size / bp));
	ivec2 b = ivec2(floor(UV * size / bp));
	int idx = b.y * nb.x + b.x;
	int total = nb.x * nb.y;
	float p_loss = clamp(rate / fps, 0.0, 1.0);
	int heal_f = max(int(round(refresh * fps)), 1);
	int reach = min(min(heal_f, 61), min(history_count - 1, n));
	int hit = -1;
	float hit_grey = 0.0;
	for (int a = 0; a <= 61; a++) {
		if (a > reach) {
			break;
		}
		float f = float(n - a);
		vec3 h = hash31(f * 1.618 + 7.0);
		if (h.x >= p_loss) {
			continue;
		}
		int start = int(floor(h.y * float(total)));
		int len = max(int(float(total) * slice * (0.25 + 0.75 * h.z)), 1);
		int rel = idx - start;
		if (rel < 0 || rel >= len) {
			continue;
		}
		float sweep = 0.25 + 0.75 * (float(b.x) + 0.5) / float(nb.x);
		int heals_at = int(round(float(heal_f) * sweep));
		if (a >= heals_at) {
			continue;
		}
		hit = a;
		hit_grey = hash11(f * 3.7 + float(rel / max(nb.x, 1)) * 0.37);
		break;
	}
	if (hit < 0) {
		COLOR = now;
	} else {
		vec4 lost = hit == 0 ? now : history_frame(hit, UV, now);
		vec4 stale = history_frame(hit + 1, UV, now);
		vec4 drift = clamp(now + (stale - lost), 0.0, 1.0);
		vec4 c = mix(stale, drift, carry);
		if (hit_grey < grey) {
			vec2 local = fract(UV * size / bp);
			float l = dot(stale.rgb, vec3(0.299, 0.587, 0.114));
			vec3 g = vec3(0.5, 0.5, 0.5) + (l - 0.5) * 0.15 + (local.y - 0.5) * 0.02;
			c = vec4(mix(g, vec3(0.32, 0.48, 0.30), 0.35) * now.a, now.a);
		}
		COLOR = vec4(c.rgb, now.a);
	}
}
