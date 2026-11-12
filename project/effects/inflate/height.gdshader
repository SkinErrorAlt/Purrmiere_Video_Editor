shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int shape_from = 1;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform float inflate : hint_range(0.0, 1.0) = 1.0;
uniform float crinkles : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 unpack2(vec4 c) {
	return vec2(floor(c.r * 255.0 + 0.5) * 256.0 + floor(c.g * 255.0 + 0.5), floor(c.b * 255.0 + 0.5) * 256.0 + floor(c.a * 255.0 + 0.5));
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y) * 2.0 - 1.0;
}

float mask_at(vec2 uv, vec2 px) {
	vec4 c = texture(effect_tex, uv + px * vec2(-0.5, -0.5)) + texture(effect_tex, uv + px * vec2(0.5, -0.5)) + texture(effect_tex, uv + px * vec2(-0.5, 0.5)) + texture(effect_tex, uv + px * vec2(0.5, 0.5));
	c *= 0.25;
	float a = max(c.a, 0.0001);
	float l = dot(clamp(c.rgb / a, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722));
	float m = c.a;
	if (shape_from == 1) {
		m = l * c.a;
	} else if (shape_from == 2) {
		m = (1.0 - l) * c.a;
	}
	float th = shape_from == 0 ? 0.5 : threshold;
	return clamp((m - th) / 0.04 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 qsize = max(tex_size, vec2(1.0));
	vec2 full = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	vec2 pq = UV * qsize;
	ivec2 base = ivec2(floor(pq - 0.5));
	float best = 1e20;
	vec2 bs = vec2(0.0);
	for (int y = -1; y <= 2; y++) {
		for (int x = -1; x <= 2; x++) {
			ivec2 at = clamp(base + ivec2(x, y), ivec2(0), ivec2(qsize) - 1);
			vec2 s = unpack2(texelFetch(TEXTURE, at, 0));
			if (s.x > 65000.0) {
				continue;
			}
			vec2 dv = (s + 0.5) - pq;
			float dd = dot(dv, dv);
			if (dd < best) {
				best = dd;
				bs = s + 0.5;
			}
		}
	}
	float m = mask_at(UV, 1.0 / full);
	float d = best > 1e19 ? 0.0 : sqrt(best) / qsize.y;
	float d0 = 0.0015;
	float prof = (sqrt(d + d0) - sqrt(d0)) / 0.45;
	vec2 sp = bs / qsize.y;
	float wav = noise2(sp * 40.0 + float(seed) * 7.1) * 0.65 + noise2(sp * 95.0 + float(seed) * 3.3) * 0.35;
	float ridge = 0.5 - abs(wav);
	float env = exp(-d / 0.03) * smoothstep(0.0, 0.006, d);
	float h = clamp(prof * inflate * m, 0.0, 1.0);
	float cr = clamp(0.5 + 0.5 * crinkles * ridge * env * inflate * m, 0.0, 1.0);
	float hi = floor(h * 255.0) / 255.0;
	COLOR = vec4(hi, fract(h * 255.0), cr, 1.0);
}
