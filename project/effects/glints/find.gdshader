shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.6;
uniform float texture_needed : hint_range(0.0, 1.0) = 0.35;
uniform float density : hint_range(0.0, 1.0) = 0.45;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float whiteness : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float lum_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, LUMA) * c.a;
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	float stp = max(px_scale, 0.5);
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l0 = dot(rgb, LUMA) * c.a;
	float peak = 0.0;
	float mean = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			if (i == 0 && j == 0) {
				continue;
			}
			float l = lum_at(TEXTURE, UV + vec2(float(i), float(j)) * px * stp);
			peak = max(peak, l);
			mean += l;
		}
	}
	mean /= 24.0;
	float wide = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		wide += lum_at(TEXTURE, UV + vec2(cos(a), sin(a)) * px * stp * 6.0);
	}
	wide /= 8.0;
	float is_peak = step(peak, l0 - 0.0005);
	float bright = smoothstep(threshold, mix(threshold, 1.0, 0.35) + 0.01, l0);
	float need = mix(0.01, 0.2, clamp(texture_needed, 0.0, 1.0));
	float stands = smoothstep(need, need * 2.0 + 0.02, l0 - min(mean, wide));
	vec2 cell = floor(UV * vec2(1920.0, 1080.0) / 2.0) + vec2(float(seed) * 7.31, float(seed) * 3.17);
	float h1 = hash12(cell);
	float h2 = hash12(cell + 19.7);
	float h3 = hash12(cell + 41.3);
	float rate = mix(0.5, 1.7, h2);
	float t = clip_time * speed * rate * 2.4 + h1 * 6.2831853;
	float tw = speed > 0.0001 ? pow(max(sin(t), 0.0), 8.0) : smoothstep(0.55, 1.0, h1);
	float keep = step(h3, clamp(density, 0.0, 1.0));
	float g = is_peak * bright * stands * tw * keep;
	vec3 col = mix(rgb, vec3(1.0), clamp(whiteness, 0.0, 1.0)) * g;
	COLOR = vec4(sqrt(clamp(col * 0.5, 0.0, 1.0)), 1.0);
}
