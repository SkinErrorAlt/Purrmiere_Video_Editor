shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 2) = 0;
uniform vec2 origin = vec2(0.5, 0.6);
uniform int count : hint_range(4, 160) = 90;
uniform float size : hint_range(0.003, 0.08) = 0.022;
uniform float power : hint_range(0.0, 3.0) = 1.1;
uniform float gravity : hint_range(0.0, 3.0) = 0.9;
uniform float flutter : hint_range(0.0, 1.0) = 0.6;
uniform int colourful : hint_range(0, 2) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.3, 0.5, 1.0);
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.3, 20.0) = 3.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float clip_time;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 palette(float h) {
	if (colourful == 2) {
		return colour.rgb * mix(0.75, 1.1, h);
	}
	if (colourful == 1) {
		return h < 0.5 ? vec3(1.0, 0.78, 0.25) * mix(0.8, 1.1, h * 2.0) : vec3(0.85, 0.87, 0.9) * mix(0.8, 1.1, h * 2.0 - 1.0);
	}
	int k = int(floor(h * 6.0));
	if (k == 0) {
		return vec3(1.0, 0.25, 0.35);
	}
	if (k == 1) {
		return vec3(1.0, 0.8, 0.15);
	}
	if (k == 2) {
		return vec3(0.25, 0.8, 0.4);
	}
	if (k == 3) {
		return vec3(0.25, 0.6, 1.0);
	}
	if (k == 4) {
		return vec3(0.7, 0.35, 1.0);
	}
	return vec3(1.0, 0.5, 0.15);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clip_time - starts_at;
	if (t < 0.0 || t > duration) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 at = vec2(UV.x * asp, UV.y);
		float sd = float(seed) * 3.17;
		float fade = 1.0 - smoothstep(duration * 0.8, duration, t);
		vec3 rgb = c.rgb;
		float al = c.a;
		float aa = 1.2 / sz.y;
		for (int i = 0; i < 160; i++) {
			if (i >= count) {
				break;
			}
			float fi = float(i);
			float h1 = hash(vec2(fi, sd + 1.0));
			float h2 = hash(vec2(fi, sd + 2.0));
			float h3 = hash(vec2(fi, sd + 3.0));
			float h4 = hash(vec2(fi, sd + 4.0));
			float h5 = hash(vec2(fi, sd + 5.0));
			vec2 pos = vec2(0.0);
			float drag = 1.6;
			if (mode == 1) {
				float lt = t + h4 * duration * 0.5;
				pos = vec2(h1 * asp, -0.05 + gravity * 0.18 * lt * mix(0.7, 1.3, h2));
				pos.x += sin(lt * mix(2.0, 4.0, h3) + h5 * 6.28) * 0.04 * flutter;
			} else {
				vec2 o = vec2(origin.x * asp, origin.y);
				float ang = (h1 - 0.5) * 1.9 - 1.5707963;
				if (mode == 2) {
					bool left = h5 < 0.5;
					o = vec2(left ? 0.0 : asp, 1.02);
					ang = (left ? -1.05 : -2.09) + (h1 - 0.5) * 0.6;
				}
				float sp = power * mix(0.5, 1.3, h2) * (mode == 2 ? 1.4 : 1.0);
				float k = 1.0 - exp(-drag * t);
				pos = o + vec2(cos(ang), sin(ang)) * sp * k / drag;
				pos.y += gravity * 0.25 * t * t / (1.0 + t * 0.6);
				pos.x += sin(t * mix(3.0, 6.0, h3) + h5 * 6.28) * 0.03 * flutter * smoothstep(0.2, 0.8, t);
			}
			vec2 p = at - pos;
			float s = size * mix(0.6, 1.4, h3);
			if (dot(p, p) > s * s * 4.0) {
				continue;
			}
			float a = h4 * 6.28 + t * mix(2.0, 8.0, h1);
			p = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y);
			float sq = abs(cos(t * mix(4.0, 12.0, h2) * flutter + h5 * 6.28));
			vec2 half_size = vec2(s, s * 0.55 * max(sq, 0.12));
			vec2 q = abs(p) - half_size;
			float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
			float cov = (1.0 - smoothstep(-aa, aa, d)) * fade;
			vec3 col = palette(h5) * mix(0.75, 1.0, sq);
			rgb = rgb * (1.0 - cov) + col * cov;
			al = al + cov * (1.0 - al);
		}
		COLOR = vec4(rgb, al);
	}
}
