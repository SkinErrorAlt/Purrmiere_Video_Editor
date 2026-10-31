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

uniform vec4 tint : source_color = vec4(0.25, 1.0, 0.35, 1.0);
uniform float gain : hint_range(0.5, 8.0) = 2.2;
uniform float noise : hint_range(0.0, 1.0) = 0.25;
uniform float mask : hint_range(0.0, 1.0) = 0.6;
uniform float scan : hint_range(0.0, 1.0) = 0.2;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	luma = pow(clamp(luma * gain, 0.0, 4.0), 0.75);
	float n = hash12(UV * size * 0.6 + floor(time * 30.0) * 9.1) - 0.5;
	luma += n * noise;
	float gap = max(3.0 * max(px_scale, 0.0001), 1.0);
	float line = abs(fract(UV.y * size.y / gap) - 0.5) * 2.0;
	luma *= mix(1.0, 0.7 + 0.3 * line, scan);
	vec2 aspect = vec2(max(size.x, 1.0) / max(size.y, 1.0), 1.0);
	float r = length((UV - vec2(0.5)) * aspect) * 1.6;
	luma *= mix(1.0, 1.0 - smoothstep(0.55, 1.0, r), mask);
	rgb = tint.rgb * luma;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
