shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 point_a = vec2(0.33, 0.5);
uniform float pull_a : hint_range(-1.0, 1.0) = 0.4;
uniform vec2 point_b = vec2(0.67, 0.5);
uniform float pull_b : hint_range(-1.0, 1.0) = -0.4;
uniform float reach : hint_range(0.02, 1.0) = 0.3;
uniform int edge : hint_range(0, 2) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);

vec2 pull_at(vec2 pos, vec2 at, float amount, float ar) {
	vec2 d = pos - at;
	d.x *= ar;
	float r = length(d);
	float k = max(reach, 0.02);
	float fall = k * k / (r * r + k * k);
	vec2 dir = r > 0.00001 ? d / r : vec2(0.0);
	vec2 push = dir * amount * k * fall;
	push.x /= ar;
	return push;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		float ar = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
		vec2 src = UV + pull_at(UV, point_a, pull_a, ar) + pull_at(UV, point_b, pull_b, ar);
		vec4 col;
		if (src.x >= 0.0 && src.x <= 1.0 && src.y >= 0.0 && src.y <= 1.0) {
			col = texture(TEXTURE, src);
		} else if (edge == 1) {
			col = texture(TEXTURE, 1.0 - abs(1.0 - mod(src, 2.0)));
		} else if (edge == 2) {
			col = vec4(0.0);
		} else {
			col = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
		}
		COLOR = mix(base, col, strength);
	}
}
