shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float amount : hint_range(0.0, 100.0) = 12.0;
uniform int mode : hint_range(0, 1) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform int samples : hint_range(3, 12) = 8;
uniform vec2 centre = vec2(0.5, 0.5);

float bell(float x, float c, float w) {
	float k = (x - c) / w;
	return exp(-k * k);
}

vec3 spectral(float t) {
	float r = bell(t, 0.02, 0.26) + 0.35 * bell(t, 1.0, 0.16);
	float g = bell(t, 0.47, 0.22);
	float b = bell(t, 0.86, 0.22);
	return vec3(r, g, b);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	int n = clamp(samples, 3, 12);
	vec2 off_px;
	if (mode == 0) {
		vec2 d = (UV - centre) * size;
		off_px = d / (0.5 * length(size)) * amount * ps;
	} else {
		float rad = radians(angle);
		off_px = vec2(cos(rad), sin(rad)) * amount * ps;
	}
	vec2 off_uv = off_px / size;
	vec3 acc = vec3(0.0);
	vec3 asum = vec3(0.0);
	vec3 wsum = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		if (i >= n) {
			break;
		}
		float t = float(i) / float(n - 1);
		vec3 w = spectral(t);
		vec4 s = texture(TEXTURE, clamp(UV + off_uv * (t - 0.5), vec2(0.0), vec2(1.0)));
		acc += s.rgb * w;
		asum += vec3(s.a) * w;
		wsum += w;
	}
	vec3 safe = max(wsum, vec3(0.0001));
	vec3 rgb = acc / safe;
	vec3 ac = asum / safe;
	float oa = clamp(max(ac.r, max(ac.g, ac.b)), 0.0, 1.0);
	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(oa)), oa);
}
