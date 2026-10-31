shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float block_size : hint_range(1.0, 400.0) = 16.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float feather : hint_range(0.0, 0.5) = 0.02;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

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
	float ps = max(px_scale, 0.0001);
	float bs = max(block_size * ps, 1.0);
	vec2 cid = floor(UV * sz / bs);
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	float t = hash12(cid + skey);
	float keep = wipe_keep(t, progress, feather);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
