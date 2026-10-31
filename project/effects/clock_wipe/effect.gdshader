shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float start_angle : hint_range(-180.0, 180.0) = -90.0;
uniform bool clockwise = true;
uniform float feather : hint_range(0.0, 0.5) = 0.005;
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
	vec2 d = (UV - centre) * vec2(sz.x / sz.y, 1.0);
	if (abs(d.x) + abs(d.y) < 0.0000001) { d = vec2(0.0000001, 0.0); }
	float ang = atan(d.y, d.x) - radians(start_angle);
	float t = fract(ang / 6.2831853 + 2.0);
	if (!clockwise) { t = 1.0 - t; }
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
