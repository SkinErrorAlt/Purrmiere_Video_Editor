shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int slices = 6;
uniform float angle : hint_range(-90.0, 90.0) = 0.0;
uniform bool alternate = true;
uniform float stagger : hint_range(0.0, 0.9) = 0.45;
uniform int curve = 2;

float slice_time(float t) {
	if (curve == 2) {
		float u = 1.0 - t;
		return 1.0 - u * u * u;
	}
	return tr_ease(t, curve == 1 ? 3 : 0);
}

vec4 slice_colour(vec2 uv, vec2 w, vec2 d, float id, float n, float len) {
	float o = n > 1.0 ? id / (n - 1.0) : 0.0;
	float st = clamp(stagger, 0.0, 0.9);
	float lp = slice_time(clamp((progress - o * st) / (1.0 - st), 0.0, 1.0));
	float side = (alternate && mod(id, 2.0) > 0.5) ? -1.0 : 1.0;
	float off = (1.0 - lp) * (len + 0.05) * side;
	vec2 suv = tr_frame_uv(w - d * off);
	vec2 inset = min(suv, 1.0 - suv) * frame_px;
	float cov = clamp(min(inset.x, inset.y) + 0.5, 0.0, 1.0);
	return mix(from_at(uv), to_clamped(suv), cov);
}

vec4 transition(vec2 uv) {
	float ratio = tr_ratio();
	vec2 w = tr_world(uv);
	float rad = radians(angle);
	vec2 d = vec2(cos(rad), sin(rad));
	vec2 nrm = vec2(d.y, -d.x);
	float span = abs(nrm.x) * ratio + abs(nrm.y);
	float len = abs(d.x) * ratio + abs(d.y);
	float n = float(max(slices, 1));
	float across = (dot(w, nrm) / span + 0.5) * n;
	float id = clamp(floor(across), 0.0, n - 1.0);
	vec4 col = slice_colour(uv, w, d, id, n, len);
	float fx = across - floor(across);
	float band_px = span * frame_px.y / n;
	float other = fx > 0.5 ? id + 1.0 : id - 1.0;
	float dist = (fx > 0.5 ? 1.0 - fx : fx) * band_px;
	if (other >= 0.0 && other <= n - 1.0 && dist < 0.5) {
		col = mix(col, slice_colour(uv, w, d, other, n, len), 0.5 - dist);
	}
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
