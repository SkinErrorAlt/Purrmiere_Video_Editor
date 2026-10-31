shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform int rings = 3;
uniform float ring_size : hint_range(0.2, 2.0) = 1.0;
uniform float zoom : hint_range(0.0, 0.6) = 0.25;
uniform float switch_at : hint_range(0.3, 0.95) = 0.8;

float boundary(float k, float z) {
	float j = k - 1.0;
	float base = 1.0 + 0.6 * j + 0.1 * j * (j - 1.0);
	float grow = 1.0 + 0.5 * j + 0.25 * j * (j - 1.0);
	return (base * 0.5 * max(ring_size, 0.05) + grow * z) * tr_ratio() * 0.5;
}

vec4 ring_colour(vec2 c, vec2 p, float idx, float n, float pro, float fade) {
	float level = idx < 0.5 ? 0.0 : (n > 1.5 ? 0.6 + 0.4 * (idx - 1.0) / (n - 1.0) : 1.0);
	float t = fade;
	if (idx > 0.5 && idx < n - 0.5) {
		t = pow(fade, 1.0 + idx);
	}
	float mag = 1.0 / max(1.0 - clamp(zoom, 0.0, 0.6) * level * pro, 0.2);
	float mag_to = 1.0 + (mag - 1.0) * (1.0 - t);
	vec4 a = from_at(tr_frame_uv(c + p / mag));
	vec4 b = to_at(tr_frame_uv(c + p / mag_to));
	return mix(a, b, t);
}

vec4 transition(vec2 uv) {
	float n = float(clamp(rings, 1, 8));
	float sw = clamp(switch_at, 0.05, 0.98);
	float pro = progress / sw;
	float z = pro * 0.2;
	if (pro > 1.0) {
		z = 0.2 + (pro - 1.0) * 5.0;
	}
	float fade = clamp((progress - sw) / (1.0 - sw), 0.0, 1.0);
	fade = fade * fade * (3.0 - 2.0 * fade);
	vec2 c = tr_world(centre);
	vec2 p = tr_world(uv) - c;
	float d = length(p);
	float idx = n;
	float lo = 0.0;
	float hi = 1000000.0;
	for (int i = 1; i <= 8; i++) {
		float k = float(i);
		if (k > n) {
			break;
		}
		float b = boundary(k, z);
		if (d < b) {
			idx = k - 1.0;
			hi = b;
			break;
		}
		lo = b;
	}
	vec4 col = ring_colour(c, p, idx, n, pro, fade);
	float px = frame_px.y;
	float to_hi = (hi - d) * px;
	float to_lo = (d - lo) * px;
	if (idx < n && to_hi < 0.5) {
		col = mix(col, ring_colour(c, p, idx + 1.0, n, pro, fade), 0.5 - to_hi);
	} else if (idx > 0.0 && to_lo < 0.5) {
		col = mix(col, ring_colour(c, p, idx - 1.0, n, pro, fade), 0.5 - to_lo);
	}
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
