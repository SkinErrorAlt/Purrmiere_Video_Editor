shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) { break; }
		sum += value_noise(p) * amp;
		total += amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return total > 0.0 ? sum / total : 0.0;
}

uniform int levels : hint_range(2, 64) = 6;
uniform bool luma_only = false;
uniform float dither : hint_range(0.0, 1.0) = 0.0;
uniform float gamma_v : hint_range(0.2, 4.0) = 1.0;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float n = float(max(levels, 2)) - 1.0;
	float d = (hash12(UV * max(tex_size, vec2(1.0))) - 0.5) * dither / n;
	if (luma_only) {
		float luma = clamp(dot(rgb, vec3(0.2126, 0.7152, 0.0722)) + d, 0.0, 1.0);
		float q = floor(pow(luma, gamma_v) * n + 0.5) / n;
		rgb = rgb * (luma > 0.0001 ? pow(q, 1.0 / gamma_v) / luma : 0.0);
	} else {
		vec3 lin = clamp(pow(max(rgb, vec3(0.0)), vec3(gamma_v)) + vec3(d), 0.0, 1.0);
		rgb = pow(floor(lin * n + 0.5) / n, vec3(1.0 / gamma_v));
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
