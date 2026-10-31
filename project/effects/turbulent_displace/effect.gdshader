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
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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

uniform float amount : hint_range(0.0, 400.0) = 30.0;
uniform float scale_n : hint_range(0.1, 40.0) = 4.0;
uniform int octaves : hint_range(1, 8) = 4;
uniform float speed : hint_range(-8.0, 8.0) = 0.5;
uniform bool vertical_only = false;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = UV * scale_n + vec2(0.0, time * speed);
	float nx = fbm(p, octaves) - 0.5;
	float ny = fbm(p + vec2(37.2, 11.7), octaves) - 0.5;
	vec2 off = vec2(vertical_only ? 0.0 : nx, ny) * amount * max(px_scale, 0.0001) / size;
	COLOR = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
}
