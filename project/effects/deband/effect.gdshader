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

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(1.0, 32.0) = 8.0;
uniform float dither : hint_range(0.0, 1.0) = 0.4;
uniform float threshold : hint_range(0.0, 0.2) = 0.03;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float r = radius * max(px_scale, 0.0001);
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		float ang = float(i) / 4.0 * 6.28318530718;
		vec2 off = vec2(cos(ang), sin(ang)) * r / size;
		vec4 s1 = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
		vec4 s2 = texture(TEXTURE, clamp(UV - off, vec2(0.0), vec2(1.0)));
		sum += (s1.a > 0.0001 ? s1.rgb / s1.a : vec3(0.0)) + (s2.a > 0.0001 ? s2.rgb / s2.a : vec3(0.0));
		total += 2.0;
	}
	vec3 around = sum / max(total, 0.0001);
	float flat_here = 1.0 - smoothstep(threshold, threshold * 3.0, length(around - rgb));
	rgb = mix(rgb, around, strength * flat_here);
	float n = hash12(UV * size) - 0.5;
	rgb += n * dither * flat_here / 255.0 * 4.0;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
