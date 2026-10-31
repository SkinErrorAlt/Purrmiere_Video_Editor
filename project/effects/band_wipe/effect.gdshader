shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int bands : hint_range(1, 64) = 8;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
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
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	vec2 perp = vec2(-dir.y, dir.x);
	float span_a = max(asp * abs(dir.x) + abs(dir.y), 0.0001);
	float span_p = max(asp * abs(perp.x) + abs(perp.y), 0.0001);
	float along = clamp(dot(pos, dir) / span_a + 0.5, 0.0, 1.0);
	float across = clamp(dot(pos, perp) / span_p + 0.5, 0.0, 0.99999);
	float band = floor(across * float(max(bands, 1)));
	float t = mod(band, 2.0) > 0.5 ? 1.0 - along : along;
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
