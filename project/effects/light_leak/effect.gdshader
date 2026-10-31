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

uniform vec4 colour : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform int edge : hint_range(0, 3) = 1;
uniform float reach : hint_range(0.0, 1.0) = 0.45;
uniform float strength : hint_range(0.0, 2.0) = 0.7;
uniform float softness : hint_range(0.0, 1.0) = 0.7;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float d = UV.x;
	if (edge == 1) { d = 1.0 - UV.x; }
	else if (edge == 2) { d = UV.y; }
	else if (edge == 3) { d = 1.0 - UV.y; }
	float wash = 1.0 - smoothstep(0.0, max(reach, 0.0001), d);
	wash = mix(wash, wash * wash * (3.0 - 2.0 * wash), softness);
	float f = 1.0 - flicker * 0.5 * (1.0 - value_noise(vec2(time * 3.0, 0.0)));
	rgb += colour.rgb * wash * strength * colour.a * f;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
