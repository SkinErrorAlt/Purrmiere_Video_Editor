shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int cells : hint_range(1, 64) = 8;
uniform int direction : hint_range(0, 3) = 1;
uniform float stagger : hint_range(0.0, 1.0) = 1.0;
uniform float feather : hint_range(0.0, 0.5) = 0.01;
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
	float cpx = sz.x / float(max(cells, 1));
	vec2 g = UV * sz / max(cpx, 0.0001);
	vec2 cid = floor(g);
	vec2 f = g - cid;
	float parity = mod(cid.x + cid.y, 2.0);
	float u;
	if (direction == 0) {
		u = 1.0 - f.x;
		parity = 1.0 - parity;
	} else if (direction == 2) {
		u = 1.0 - f.y;
		parity = 1.0 - parity;
	} else if (direction == 3) {
		u = f.y;
	} else {
		u = f.x;
	}
	float sg = clamp(stagger, 0.0, 1.0);
	float t = (u + sg * parity) / (1.0 + sg);
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
