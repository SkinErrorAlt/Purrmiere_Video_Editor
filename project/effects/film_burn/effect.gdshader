shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.6;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.28, 0.62);
uniform vec4 burn_colour : source_color = vec4(1.0, 0.34, 0.05, 1.0);
uniform vec4 core_colour : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float ragged : hint_range(0.0, 1.0) = 0.6;
uniform float flicker : hint_range(0.0, 1.0) = 0.5;
uniform float white_out : hint_range(0.0, 1.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 5; i++) {
		s += w * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		w *= 0.5;
	}
	return s / 0.97;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 p = vec2((UV.x - centre.x) * asp, UV.y - centre.y);
		float sd = float(seed) * 7.31 + 3.7;
		float fl = clamp(flicker, 0.0, 1.0);
		float rg = clamp(ragged, 0.0, 1.0);
		float drift = clip_time * (0.4 + 1.6 * fl);
		float n1 = fbm(p * 2.6 + vec2(sd, sd * 0.61) + vec2(drift * 0.3, -drift * 0.5));
		float n2 = fbm(p * 8.0 + vec2(-sd, drift * 1.3));
		float dist = length(p) + (n1 - 0.5) * 1.1 * rg + (n2 - 0.5) * 0.3 * rg;
		float e = g * g * (3.0 - 2.0 * g);
		float far_corner = 0.0;
		far_corner = max(far_corner, length(vec2(-centre.x * asp, -centre.y)));
		far_corner = max(far_corner, length(vec2((1.0 - centre.x) * asp, -centre.y)));
		far_corner = max(far_corner, length(vec2(-centre.x * asp, 1.0 - centre.y)));
		far_corner = max(far_corner, length(vec2((1.0 - centre.x) * asp, 1.0 - centre.y)));
		float reach = e * (far_corner + 0.75) - 0.15;
		float inside = smoothstep(reach, reach - 0.4, dist);
		float front = smoothstep(reach + 0.3, reach, dist) * (1.0 - inside);
		float flick = 1.0 + fl * 0.35 * (vnoise(vec2(clip_time * 19.0, sd)) - 0.5);
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec3 heat = mix(burn_colour.rgb, core_colour.rgb, inside);
		float burn = clamp(inside + front * 0.85, 0.0, 1.0) * clamp(e * 1.4, 0.0, 1.0) * flick;
		vec3 tinted = rgb * mix(vec3(1.0), heat * 1.5, clamp(burn, 0.0, 1.0) * 0.3);
		vec3 glow = heat * burn * (0.75 + 0.25 * inside);
		vec3 o = 1.0 - (1.0 - clamp(tinted, 0.0, 1.0)) * (1.0 - clamp(glow, 0.0, 1.0));
		o *= mix(vec3(1.0), vec3(1.0, 0.8, 0.42), clamp(burn, 0.0, 1.0) * 0.85);
		float w = clamp(white_out, 0.0, 1.0) * smoothstep(0.8, 1.0, g) * inside;
		o = mix(o, vec3(1.0, 0.98, 0.94), w);
		float oa = max(a, clamp(burn, 0.0, 1.0));
		float ua = max(oa, w);
		COLOR = vec4(clamp(o, 0.0, 1.0) * ua, ua);
	}
}
