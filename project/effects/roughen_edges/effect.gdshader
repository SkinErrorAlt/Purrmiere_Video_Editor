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

uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float scale_n : hint_range(0.5, 60.0) = 12.0;
uniform float border : hint_range(0.0, 0.5) = 0.06;
uniform int octaves : hint_range(1, 8) = 3;
uniform vec4 edge_colour : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float n = fbm(UV * scale_n, octaves);
	float cut = border * (0.4 + n * roughness * 1.6);
	float keep = smoothstep(cut * 0.6, cut, d);
	rgb = mix(edge_colour.rgb, rgb, keep);
	float oa = a * mix(edge_colour.a, 1.0, keep);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
