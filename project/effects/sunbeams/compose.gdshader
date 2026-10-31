shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform vec2 sun = vec2(0.78, 0.06);
uniform float length : hint_range(0.1, 3.0) = 1.8;
uniform float count : hint_range(3.0, 60.0) = 22.0;
uniform float variety : hint_range(0.0, 1.0) = 0.5;
uniform float haze : hint_range(0.0, 1.0) = 0.55;
uniform float blocked : hint_range(0.0, 1.0) = 0.75;
uniform float speed : hint_range(0.0, 2.0) = 0.25;
uniform vec4 colour : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.85;
uniform float falloff : hint_range(0.2, 4.0) = 1.2;
uniform int seed = 7;
uniform bool beams_only = false;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float aspect = full.x / full.y;
	vec2 p = (UV - sun) * vec2(aspect, 1.0);
	float dist = length(p);
	vec2 dir = p / max(dist, 0.00001);
	float t = clip_time * speed;
	vec2 sd = vec2(float(seed % 997) * 1.731, float(seed % 769) * 2.417);
	float ring = count / 6.2831853;
	vec2 q = dir * ring + sd + vec2(t * 0.31, -t * 0.19);
	float n1 = vnoise(q);
	float n2 = vnoise(q * 2.7 + vec2(17.3, 5.1) - vec2(t * 0.23, t * 0.37));
	float n3 = vnoise(q * 0.45 + vec2(-3.7, 9.2) + vec2(t * 0.07, 0.0));
	float n = mix(n1, n1 * 0.55 + n2 * 0.45, clamp(variety, 0.0, 1.0));
	float beam = smoothstep(0.32, 0.78, n) * mix(1.0, 0.45 + 0.9 * n3, clamp(variety, 0.0, 1.0) * 0.7);
	float near = smoothstep(0.0, 0.12, dist);
	beam = mix(0.55, beam, near);
	float fall = pow(clamp(1.0 - dist / max(length, 0.01), 0.0, 1.0), max(falloff, 0.01));
	float drift = vnoise(p * 3.2 + sd * 0.37 + vec2(-t * 0.5, t * 0.21)) * 0.6 + vnoise(p * 7.1 + sd + vec2(t * 0.4, 0.0)) * 0.4;
	float hz = mix(1.0, 0.55 + 0.9 * drift, clamp(haze, 0.0, 1.0) * 0.6);
	float vis = mix(1.0, exp(-(1.0 - texture(TEXTURE, UV).r) * 5.0), clamp(blocked, 0.0, 1.0));
	float halo = exp(-dist / 0.09) * 0.7 + exp(-dist / 0.3) * 0.25;
	float amount = (beam * fall * (0.3 + 0.9 * clamp(haze, 0.0, 1.0)) * hz + halo * (0.4 + 0.6 * clamp(haze, 0.0, 1.0))) * vis;
	vec3 light = colour.rgb * colour.a * amount * intensity * 1.4;
	light += (hash12(FRAGCOORD.xy + fract(t) * 91.0) - 0.5) / 255.0 * step(0.002, amount);
	light = clamp(light, 0.0, 1.0);
	if (beams_only) {
		COLOR = vec4(light, max(light.r, max(light.g, light.b)));
	} else {
		COLOR = vec4(min(o.rgb + light * (vec3(o.a) - o.rgb * 0.6), vec3(o.a)), o.a);
	}
}
