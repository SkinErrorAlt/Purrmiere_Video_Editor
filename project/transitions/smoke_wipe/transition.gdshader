shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float density : hint_range(0.2, 1.0) = 0.85;
uniform float scale : hint_range(0.3, 3.0) = 1.0;
uniform vec4 colour : source_color = vec4(0.93, 0.93, 0.94, 1.0);
uniform float light_angle : hint_range(-180.0, 180.0) = 120.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.6;
uniform int curve = 1;

const mat2 SM_ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float sm_fbm(vec2 q) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * tr_noise(q);
		q = SM_ROT * q * 2.02 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v / 0.9375;
}

float sm_billow(vec2 q, int octaves) {
	q = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * q;
	float v = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < octaves; i++) {
		v += a * (1.0 - abs(tr_noise(q) * 2.0 - 1.0));
		n += a;
		q = SM_ROT * q * 2.03 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v / n;
}

float sm_coord(vec2 w, vec2 wc) {
	if (direction == 0) {
		return w.x / tr_ratio() + 0.5;
	} else if (direction == 1) {
		return 0.5 - w.x / tr_ratio();
	} else if (direction == 2) {
		return 0.5 - w.y;
	} else if (direction == 3) {
		return w.y + 0.5;
	}
	vec2 hr = vec2(tr_ratio() * 0.5, 0.5);
	float far = length(max(abs(wc - hr), abs(wc + hr)));
	return length(w - wc) / max(far, 0.001);
}

vec2 sm_flow(vec2 w, vec2 wc, float front) {
	float k = 2.6 / scale;
	if (direction == 4) {
		return (w - wc) * k / (1.0 + front * 1.4);
	}
	vec2 d = direction == 0 ? vec2(1.0, 0.0) : direction == 1 ? vec2(-1.0, 0.0) : direction == 2 ? vec2(0.0, -1.0) : vec2(0.0, 1.0);
	return w * k - d * front * 0.55 * k;
}

float sm_body(vec2 w, vec2 wc, float front, vec2 q, out float big) {
	big = sm_billow(q, 3);
	float s = sm_coord(w, wc) + (big - 0.55) * (0.2 + 0.55 * turbulence);
	float age = front - s;
	return smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(0.45, 1.15, age + (big - 0.55) * 0.5));
}

float sm_low(vec2 w, vec2 wc, float front, vec2 warp, float t) {
	vec2 q = sm_flow(w, wc, front) + warp * (0.7 + 1.8 * turbulence) + vec2(t * 0.3, -t * 0.2);
	float big;
	float body = sm_body(w, wc, front, q, big);
	return body * (0.35 + 1.0 * big);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float pe = tr_ease(p, curve == 1 ? 3 : curve == 2 ? 2 : 0);
	float front = mix(-0.2, 1.55, pe);
	vec2 w = tr_world(uv);
	vec2 wc = tr_world(centre);
	vec2 q0 = sm_flow(w, wc, front) * 0.35;
	vec2 warp = vec2(sm_fbm(q0 + vec2(0.0, p * 2.6)), sm_fbm(q0 + vec2(5.2, 1.3) - vec2(p * 2.2, 0.0))) - 0.5;
	float fade = smoothstep(0.0, 0.06, p) * (1.0 - smoothstep(0.72, 1.0, p));
	vec2 q = sm_flow(w, wc, front) + warp * (0.7 + 1.8 * turbulence) + vec2(p * 0.3, -p * 0.2);
	float big;
	float body = sm_body(w, wc, front, q, big);
	float low = body * (0.35 + 1.0 * big) * fade;
	float fine = sm_billow(q * 2.7 + vec2(p * 0.6, 3.1), 3);
	float wisp = mix(1.0, smoothstep(0.3, 0.85, fine), 0.85 * (1.0 - smoothstep(0.2, 0.75, body)));
	float fine2 = sm_billow(q * 7.5 + vec2(-p * 0.9, 8.1), 3);
	float erode = mix(1.0, smoothstep(0.3, 0.85, fine2), 0.95 * (1.0 - smoothstep(0.35, 0.98, body)));
	float d0 = low * (0.6 + 0.7 * fine) * wisp * erode;
	float la = radians(light_angle);
	vec2 ld = vec2(cos(la), sin(la)) * scale;
	float l1 = sm_low(w + ld * 0.035, wc, front, warp, p) * fade;
	float l2 = sm_low(w + ld * 0.1, wc, front, warp, p) * fade;
	float k = 1.2 + 2.8 * density;
	float alpha = 1.0 - exp(-d0 * k);
	float diffuse = clamp((low - l1) * 3.0, -1.0, 1.0);
	float shadow = exp(-max(l2 - low, 0.0) * k * 0.7);
	float core = 1.0 - 0.28 * smoothstep(0.6, 1.3, low);
	float lit = (0.85 + 0.38 * diffuse) * (0.76 + 0.24 * shadow) * core * (0.84 + 0.26 * fine);
	lit = mix(0.95 + 0.3 * diffuse, lit, smoothstep(0.12, 0.6, low)) * (0.92 + 0.16 * fine2);
	float rim = (1.0 - smoothstep(0.15, 0.6, low)) * smoothstep(0.02, 0.15, low) * clamp(diffuse * 2.0, 0.0, 1.0);
	float lum = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dark_tone = colour.rgb * 0.5;
	vec3 lit_tone = mix(colour.rgb, vec3(1.0), 0.04 + 0.2 * (1.0 - lum));
	vec3 smoke = mix(dark_tone, lit_tone, clamp((lit - 0.1) / 0.8, 0.0, 1.2)) + vec3(0.12 + 0.2 * lum) * rim;
	smoke = clamp(smoke, vec3(0.0), vec3(1.0));
	float sa = alpha * colour.a;
	float age_at = front - sm_coord(w, wc);
	float reveal = smoothstep(0.3, 0.44, age_at + (warp.x + warp.y) * 0.12 * turbulence + 0.7 * smoothstep(0.7, 1.0, p));
	vec4 pic = mix(from_at(uv), to_at(uv), reveal);
	return vec4(smoke * sa, sa) + pic * (1.0 - sa);
}

void fragment() {
	COLOR = transition(UV);
}
