shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float left : hint_range(0.0, 64.0) = 0.0;
uniform float top : hint_range(0.0, 64.0) = 0.0;
uniform float right : hint_range(0.0, 64.0) = 0.0;
uniform float bottom : hint_range(0.0, 64.0) = 8.0;
uniform int fill : hint_range(0, 3) = 0;

vec4 at(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 lo = vec2(left, top) * ps / size;
	vec2 hi = vec2(1.0) - vec2(right, bottom) * ps / size;
	lo = min(lo, vec2(0.45));
	hi = max(hi, vec2(0.55));
	vec2 half_px = 0.5 / size;
	vec2 good_lo = lo + half_px;
	vec2 good_hi = hi - half_px;
	vec2 inside = clamp(UV, good_lo, good_hi);
	vec2 over = UV - inside;
	if (over.x == 0.0 && over.y == 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else if (fill == 3) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else if (fill == 2) {
		vec2 m = inside - over;
		COLOR = at(TEXTURE, clamp(m, good_lo, good_hi));
	} else if (fill == 1) {
		COLOR = at(TEXTURE, inside);
	} else {
		vec2 depth = abs(over) * size;
		vec4 s = at(TEXTURE, inside);
		float n = 1.0;
		for (int i = 1; i <= 4; i++) {
			float f = float(i) / 4.0;
			vec2 spread = vec2(depth.y, depth.x) * 0.8 * f / size;
			s += at(TEXTURE, clamp(inside + spread, good_lo, good_hi));
			s += at(TEXTURE, clamp(inside - spread, good_lo, good_hi));
			n += 2.0;
		}
		COLOR = s / n;
	}
}
