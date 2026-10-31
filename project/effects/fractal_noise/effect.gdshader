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

uniform float scale_n : hint_range(0.1, 60.0) = 6.0;
uniform int octaves : hint_range(1, 8) = 5;
uniform float contrast : hint_range(0.1, 6.0) = 1.0;
uniform float speed : hint_range(-8.0, 8.0) = 0.2;
uniform int blend : hint_range(0, 4) = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float n = fbm(UV * scale_n + vec2(0.0, time * speed), octaves);
	n = clamp((n - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 cloud = tint.rgb * n;
	vec3 mixed = cloud;
	if (blend == 1) { mixed = rgb * cloud; }
	else if (blend == 2) { mixed = 1.0 - (1.0 - rgb) * (1.0 - cloud); }
	else if (blend == 3) { mixed = mix(2.0 * rgb * cloud, 1.0 - 2.0 * (1.0 - rgb) * (1.0 - cloud), step(0.5, rgb)); }
	else if (blend == 4) { mixed = rgb + cloud; }
	rgb = mix(rgb, mixed, strength);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
