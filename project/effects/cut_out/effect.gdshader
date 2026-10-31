shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform bool shape1_on = true;
uniform int shape1_kind : hint_range(0, 2) = 0;
uniform vec2 shape1_centre = vec2(0.5, 0.5);
uniform vec2 shape1_size = vec2(0.5, 0.5);
uniform float shape1_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float shape1_roundness : hint_range(0.0, 1.0) = 0.25;
uniform float shape1_softness : hint_range(0.0, 500.0) = 0.0;
uniform bool shape2_on = false;
uniform int shape2_kind : hint_range(0, 2) = 0;
uniform vec2 shape2_centre = vec2(0.3, 0.35);
uniform vec2 shape2_size = vec2(0.25, 0.3);
uniform float shape2_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float shape2_roundness : hint_range(0.0, 1.0) = 0.25;
uniform float shape2_softness : hint_range(0.0, 500.0) = 0.0;
uniform bool shape3_on = false;
uniform int shape3_kind : hint_range(0, 2) = 0;
uniform vec2 shape3_centre = vec2(0.7, 0.35);
uniform vec2 shape3_size = vec2(0.25, 0.3);
uniform float shape3_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float shape3_roundness : hint_range(0.0, 1.0) = 0.25;
uniform float shape3_softness : hint_range(0.0, 500.0) = 0.0;
uniform bool shape4_on = false;
uniform int shape4_kind : hint_range(0, 2) = 0;
uniform vec2 shape4_centre = vec2(0.5, 0.72);
uniform vec2 shape4_size = vec2(0.4, 0.2);
uniform float shape4_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float shape4_roundness : hint_range(0.0, 1.0) = 0.25;
uniform float shape4_softness : hint_range(0.0, 500.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float shape_distance(vec2 p, vec2 centre, vec2 size, float rotation, int kind, float roundness) {
	vec2 half_size = max(size * 0.5, vec2(0.0001));
	float a = radians(rotation);
	vec2 d = p - centre;
	vec2 q = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y);
	if (kind == 1) {
		float k = length(q / half_size);
		return (k - 1.0) * min(half_size.x, half_size.y);
	}
	float r = kind == 2 ? clamp(roundness, 0.0, 1.0) * min(half_size.x, half_size.y) : 0.0;
	vec2 e = abs(q) - half_size + vec2(r);
	return length(max(e, vec2(0.0))) + min(max(e.x, e.y), 0.0) - r;
}

float coverage(bool on, vec2 p, vec2 sz, vec2 centre, vec2 size, float rotation, int kind, float roundness, float softness) {
	if (!on) {
		return 0.0;
	}
	float sd = shape_distance(p, centre * sz, size * sz, rotation, kind, roundness);
	float soft = max(softness * max(px_scale, 0.0001), 0.0) + 1.0;
	return 1.0 - smoothstep(-0.5 * soft, 0.5 * soft, sd);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 p = UV * sz;
	float cov = 0.0;
	cov = max(cov, coverage(shape1_on, p, sz, shape1_centre, shape1_size, shape1_rotation, shape1_kind, shape1_roundness, shape1_softness));
	cov = max(cov, coverage(shape2_on, p, sz, shape2_centre, shape2_size, shape2_rotation, shape2_kind, shape2_roundness, shape2_softness));
	cov = max(cov, coverage(shape3_on, p, sz, shape3_centre, shape3_size, shape3_rotation, shape3_kind, shape3_roundness, shape3_softness));
	cov = max(cov, coverage(shape4_on, p, sz, shape4_centre, shape4_size, shape4_rotation, shape4_kind, shape4_roundness, shape4_softness));
	float keep = mode == 1 ? cov : 1.0 - cov;
	COLOR = c * clamp(keep, 0.0, 1.0);
}
