shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 3) = 0;
uniform float amount : hint_range(0.5, 20.0) = 3.0;
uniform bool shimmer = false;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 px = floor(UV * sz);
	float frame = shimmer ? floor(time * 24.0) : 0.0;
	vec2 salt = vec2(float(seed) * 7.13 + frame * 3.71, float(seed) * 1.97 - frame * 5.3);
	vec4 orig = texture(TEXTURE, UV);
	float r = amount * max(px_scale, 0.0001);
	vec4 o = orig;
	if (mode == 3) {
		float best = 1e9;
		for (int i = 0; i < 4; i++) {
			vec2 h = hash22(px + salt + vec2(float(i) * 19.1, float(i) * 7.7)) * 2.0 - 1.0;
			vec4 c = texture(TEXTURE, clamp((px + 0.5 + h * r) / sz, vec2(0.0), vec2(1.0)));
			float d = length(c.rgb - orig.rgb);
			if (d < best) {
				best = d;
				o = c;
			}
		}
	} else {
		vec2 h = hash22(px + salt) * 2.0 - 1.0;
		vec4 c = texture(TEXTURE, clamp((px + 0.5 + h * r) / sz, vec2(0.0), vec2(1.0)));
		if (mode == 1) {
			o = luma(c.rgb) < luma(orig.rgb) ? c : orig;
		} else if (mode == 2) {
			o = luma(c.rgb) > luma(orig.rgb) ? c : orig;
		} else {
			o = c;
		}
	}
	COLOR = o;
}
