shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 4.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int palette : hint_range(0, 4) = 0;
uniform vec4 colour_a : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.2, 0.35, 1.0);
uniform float angle : hint_range(-180.0, 180.0) = 70.0;
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform float white_out : hint_range(0.0, 1.0) = 0.8;
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
	for (int i = 0; i < 4; i++) {
		s += w * vnoise(p);
		p = p * 2.07 + vec2(13.7, 7.3);
		w *= 0.5;
	}
	return s / 0.9375;
}

vec3 pal(float t) {
	t = clamp(t, 0.0, 1.0);
	if (palette == 1) {
		vec3 a = vec3(1.0, 0.18, 0.42);
		vec3 b = vec3(1.0, 0.52, 0.12);
		vec3 c = vec3(1.0, 0.86, 0.45);
		return t < 0.5 ? mix(a, b, t * 2.0) : mix(b, c, t * 2.0 - 1.0);
	}
	if (palette == 2) {
		return clamp(0.55 + 0.5 * cos(6.2831853 * (t * 0.9 + vec3(0.0, 0.33, 0.67))), 0.0, 1.0);
	}
	if (palette == 3) {
		return mix(vec3(0.28, 0.5, 1.0), vec3(0.45, 1.0, 0.92), t);
	}
	if (palette == 4) {
		return mix(clamp(colour_a.rgb, vec3(0.0), vec3(1.0)), clamp(colour_b.rgb, vec3(0.0), vec3(1.0)), t);
	}
	return mix(vec3(1.0, 0.42, 0.08), vec3(1.0, 0.84, 0.5), t);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		vec2 p = (UV - 0.5) * vec2(asp, 1.0);
		float ext = abs(dir.x) * asp + abs(dir.y);
		float x = dot(p, dir) / ext + 0.5;
		if (is_in) {
			x = 1.0 - x;
		}
		float sd = float(seed) * 3.17 + 5.0;
		float drift = clip_time * 0.35;
		vec2 q = p * 1.6 + vec2(sd, sd * 0.37);
		float n1 = fbm(q + vec2(drift, -drift * 0.6));
		float n2 = fbm(q * 1.7 + vec2(-drift * 0.8, drift) + 9.1);
		float n3 = fbm(q * 0.8 - vec2(drift * 0.4) + 3.3);
		float e = g * g * (3.0 - 2.0 * g);
		float front = mix(-0.6, 1.5, e);
		float cover = smoothstep(0.0, 0.55, front - x + (n1 - 0.5) * 0.7);
		float blobs = clamp(0.3 + 1.6 * (n2 - 0.3), 0.0, 1.0);
		float dens = cover * mix(blobs, 1.0, smoothstep(0.6, 1.0, g));
		float inten = clamp(strength, 0.0, 1.0) * dens * (0.5 + 0.5 * e) * 2.2;
		vec3 leak = pal(n3 * 0.8 + 0.25 * (1.0 - x) + 0.1 * n2) * clamp(inten, 0.0, 1.2);
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec3 o = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * (1.0 - clamp(leak, 0.0, 1.0));
		o += max(leak - 1.0, vec3(0.0));
		float w = clamp(white_out, 0.0, 1.0) * smoothstep(0.75, 1.0, g) * clamp(dens * 1.4, 0.0, 1.0);
		o = mix(o, mix(vec3(1.0, 0.97, 0.92), pal(0.8), 0.25), w);
		float la = clamp(max(max(leak.r, leak.g), leak.b), 0.0, 1.0);
		float oa = max(max(a, la), w);
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
