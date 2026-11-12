shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float span : hint_range(0.05, 2.0) = 1.0;
uniform int direction = 0;
uniform float angle : hint_range(-180.0, 180.0) = 30.0;
uniform int bands : hint_range(0, 64) = 0;
uniform float curve : hint_range(0.25, 4.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);

float sweep(vec2 uv) {
	if (direction == 0) {
		return uv.y;
	}
	if (direction == 1) {
		return 1.0 - uv.y;
	}
	if (direction == 2) {
		return uv.x;
	}
	if (direction == 3) {
		return 1.0 - uv.x;
	}
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 d = (uv - centre) * vec2(aspect, 1.0);
	if (direction == 4 || direction == 5) {
		vec2 far_c = max(abs(centre), abs(vec2(1.0) - centre)) * vec2(aspect, 1.0);
		float r = clamp(length(d) / max(length(far_c), 0.0001), 0.0, 1.0);
		return direction == 4 ? r : 1.0 - r;
	}
	float a = radians(angle);
	vec2 dir = vec2(cos(a), sin(a));
	vec2 corner = vec2(aspect, 1.0) * 0.5;
	float half_w = abs(corner.x * dir.x) + abs(corner.y * dir.y);
	return clamp(dot((uv - vec2(0.5)) * vec2(aspect, 1.0), dir) / max(half_w * 2.0, 0.0001) + 0.5, 0.0, 1.0);
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	float s = clamp(sweep(UV), 0.0, 1.0);
	if (bands > 0) {
		s = min(floor(s * float(bands)) / float(max(bands - 1, 1)), 1.0);
	}
	s = pow(s, curve);
	float age = s * min(span * history_fps, float(history_count));
	COLOR = history_between(age, UV, now);
}
