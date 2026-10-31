shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 top_left = vec2(0.0, 0.0);
uniform vec2 top_right = vec2(1.0, 0.0);
uniform vec2 bottom_right = vec2(1.0, 1.0);
uniform vec2 bottom_left = vec2(0.0, 1.0);
uniform int steps : hint_range(4, 32) = 12;

vec2 quad_at(vec2 st, vec2 tl, vec2 tr, vec2 br, vec2 bl) {
	return mix(mix(tl, tr, st.x), mix(bl, br, st.x), st.y);
}

void fragment() {
	vec2 st = UV;
	int n = clamp(steps, 4, 32);
	for (int i = 0; i < 32; i++) {
		if (i >= n) { break; }
		vec2 got = quad_at(st, top_left, top_right, bottom_right, bottom_left);
		vec2 err = got - UV;
		vec2 dx = quad_at(st + vec2(0.001, 0.0), top_left, top_right, bottom_right, bottom_left) - got;
		vec2 dy = quad_at(st + vec2(0.0, 0.001), top_left, top_right, bottom_right, bottom_left) - got;
		float det = dx.x * dy.y - dx.y * dy.x;
		if (abs(det) < 0.0000001) { break; }
		vec2 fix = vec2(err.x * dy.y - err.y * dy.x, dx.x * err.y - dx.y * err.x) / det * 0.001;
		st -= fix;
	}
	if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, st);
	}
}
