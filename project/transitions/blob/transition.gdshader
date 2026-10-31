shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float wobble : hint_range(0.0, 0.6) = 0.22;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float softness : hint_range(0.0, 300.0) = 2.0;
uniform int curve = 1;
uniform float border : hint_range(0.0, 60.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

vec4 shape_consts(float e) {
	float t = e * speed * TR_PI * 2.0;
	return vec4(tr_hash(vec2(3.1, 7.7)) * 6.2831853 + t, tr_hash(vec2(11.3, 2.9)) * 6.2831853 - t * 1.3, tr_hash(vec2(5.9, 13.1)) * 6.2831853 + t * 0.7, clamp(wobble, 0.0, 0.8) / 1.2);
}

float field(vec2 p, float e, vec4 k) {
	float l = length(p);
	if (l < 0.000001) {
		return 0.0;
	}
	float a = atan(p.y, p.x);
	float w = sin(3.0 * a + k.x) * 0.5 + sin(5.0 * a + k.y) * 0.3 + sin(2.0 * a + k.z) * 0.4;
	return l / (1.0 + k.w * w);
}

vec2 perim(float t, vec2 h) {
	t = mod(t, 4.0);
	if (t < 1.0) {
		return vec2(mix(-h.x, h.x, t), h.y);
	} else if (t < 2.0) {
		return vec2(h.x, mix(h.y, -h.y, t - 1.0));
	} else if (t < 3.0) {
		return vec2(mix(h.x, -h.x, t - 2.0), -h.y);
	}
	return vec2(-h.x, mix(-h.y, h.y, t - 3.0));
}

float reach(vec2 c, float e, vec4 k) {
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float m = 0.0;
	float t1 = 0.0;
	float t2 = 0.0;
	float t3 = 0.0;
	float v1 = -1.0;
	float v2 = -1.0;
	float v3 = -1.0;
	for (int i = 0; i < 96; i++) {
		float t = float(i) / 24.0;
		float v = field(perim(t, h) - c, e, k);
		if (v > v1) {
			v3 = v2;
			t3 = t2;
			v2 = v1;
			t2 = t1;
			v1 = v;
			t1 = t;
		} else if (v > v2) {
			v3 = v2;
			t3 = t2;
			v2 = v;
			t2 = t;
		} else if (v > v3) {
			v3 = v;
			t3 = t;
		}
	}
	m = v1;
	for (int j = 0; j < 3; j++) {
		float mid = j == 0 ? t1 : (j == 1 ? t2 : t3);
		float lo = mid - 1.0 / 24.0;
		float hi = mid + 1.0 / 24.0;
		for (int i = 0; i < 10; i++) {
			float a = mix(lo, hi, 0.382);
			float b = mix(lo, hi, 0.618);
			float fa = field(perim(a, h) - c, e, k);
			float fb = field(perim(b, h) - c, e, k);
			m = max(m, max(fa, fb));
			if (fa < fb) {
				lo = a;
			} else {
				hi = b;
			}
		}
	}
	return m + 0.25 / max(frame_px.y, 1.0);
}

vec4 transition(vec2 uv) {
	float e = curve == 1 ? 0.5 * progress + 0.5 * tr_ease(progress, 3) : clamp(progress, 0.0, 1.0);
	vec4 k = shape_consts(e);
	vec2 c = tr_world(centre);
	float f = field(tr_world(uv) - c, e, k);
	float px = 1.0 / max(frame_px.y, 1.0);
	float s = max(softness * px_scale * px, 1.5 * px);
	float bw = max(border, 0.0) * px_scale * px;
	float full = reach(c, e, k) + s + bw;
	float r = direction == 0 ? e * full : (1.0 - e) * full;
	float edge_out = 1.0 - smoothstep(r - s, r, f);
	float edge_in = 1.0 - smoothstep(r - bw - s, r - bw, f);
	float amount = direction == 0 ? edge_out : 1.0 - edge_out;
	vec4 col = mix(from_at(uv), to_at(uv), amount);
	float ring = clamp(edge_out - edge_in, 0.0, 1.0) * border_colour.a;
	return tr_over(vec4(border_colour.rgb, 1.0) * ring, col);
}

void fragment() {
	COLOR = transition(UV);
}
