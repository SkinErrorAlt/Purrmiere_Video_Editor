shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int direction : hint_range(0, 1) = 0;
uniform float angle : hint_range(-90.0, 90.0) = 0.0;
uniform float feather : hint_range(0.0, 0.5) = 0.02;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);

float wipe_keep(float t, float prog, float soft_in) {
	float s = max(soft_in, 0.0001);
	float e = clamp(prog, 0.0, 1.0) * (1.0 + 2.0 * s) - s;
	return smoothstep(e - s, e + s, t);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	vec2 pos = (UV - 0.5) * vec2(asp, 1.0);
	float rad = radians(angle) + (direction == 1 ? 1.5707963 : 0.0);
	vec2 n = vec2(cos(rad), sin(rad));
	float span = max(0.5 * (asp * abs(n.x) + abs(n.y)), 0.0001);
	float t = clamp(abs(dot(pos, n)) / span, 0.0, 1.0);
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
