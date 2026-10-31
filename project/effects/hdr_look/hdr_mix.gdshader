shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D stats_tex : filter_linear, repeat_disable;
uniform sampler2D ab_tex : filter_linear, repeat_disable;
uniform int style : hint_range(0, 3) = 0;
uniform float strength : hint_range(0.0, 100.0) = 60.0;
uniform float saturation : hint_range(-100.0, 100.0) = 20.0;
uniform float detail : hint_range(0.0, 100.0) = 50.0;
uniform float smoothing : hint_range(0.0, 100.0) = 40.0;
uniform float keep_skin : hint_range(0.0, 100.0) = 70.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const vec4 LIFT = vec4(1.3, 1.8, 1.4, 2.2);
const vec4 PULL = vec4(0.14, 0.2, 0.24, 0.08);
const vec4 PIVOT = vec4(0.45, 0.45, 0.42, 0.58);
const vec4 HALO = vec4(0.22, 0.42, 0.65, 0.3);
const vec4 GAIN = vec4(1.2, 1.8, 2.4, 1.2);
const vec4 GRIT = vec4(0.4, 0.8, 1.5, 0.45);
const vec4 COLOUR = vec4(0.2, 0.32, -0.3, 0.2);

vec2 decode(vec4 e) {
	return vec2(e.r * 255.0 + e.g, e.b * 255.0 + e.a) / 255.0;
}

vec2 cubic_decoded(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	vec2 a = decode(texture(tex, vec2(h0.x, h0.y)));
	vec2 b = decode(texture(tex, vec2(h1.x, h0.y)));
	vec2 c = decode(texture(tex, vec2(h0.x, h1.y)));
	vec2 d = decode(texture(tex, vec2(h1.x, h1.y)));
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

float pick(vec4 v) {
	if (style == 1) {
		return v.y;
	}
	if (style == 2) {
		return v.z;
	}
	if (style == 3) {
		return v.w;
	}
	return v.x;
}

float luma_at(vec2 uv) {
	vec4 c = texture(effect_tex, uv);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	return dot(rgb, LUMA);
}

float skin_mask(vec3 rgb) {
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	float warm = smoothstep(0.0, 0.05, rgb.r - rgb.g) * smoothstep(-0.02, 0.06, rgb.g - rgb.b);
	return warm * smoothstep(0.12, 0.2, sat) * (1.0 - smoothstep(0.55, 0.7, sat)) * smoothstep(0.25, 0.4, mx);
}

float soft_into(float delta, float i) {
	if (delta < 0.0) {
		return i < 0.00001 ? 0.0 : -i * (1.0 - exp(delta / i));
	}
	float room = 1.0 - i;
	return room < 0.00001 ? 0.0 : room * (1.0 - exp(-delta / room));
}

vec3 apply_luma(vec3 rgb, float i, float delta) {
	float l = clamp(i + delta, 0.0, 1.0);
	if (i < 0.0001) {
		return vec3(l);
	}
	vec3 d = rgb - vec3(i);
	float k = pow(l / i, 0.7);
	for (int c = 0; c < 3; c++) {
		if (d[c] > 0.00001) {
			k = min(k, (1.0 - l) / d[c]);
		} else if (d[c] < -0.00001) {
			k = min(k, l / -d[c]);
		}
	}
	return vec3(l) + d * max(k, 0.0);
}

float tone(float x, float s) {
	float m = pick(PIVOT);
	float a = s * pick(LIFT);
	float pull = s * pick(PULL);
	if (x <= m) {
		float u = x / m;
		return m * (1.0 + a) * u / (1.0 + a * u);
	}
	float u = (x - m) / (1.0 - m);
	float k0 = 1.0 / (1.0 + a);
	return m + (1.0 - m) * (u * k0 + (1.0 - pull - k0) * u * u);
}

vec3 push_colour(vec3 rgb, float amount) {
	float l = dot(rgb, LUMA);
	vec3 d = rgb - vec3(l);
	float chroma = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
	float t = 1.0 + amount * (amount > 0.0 ? (1.0 - 0.7 * chroma) : 1.0);
	t = max(t, 0.0);
	float tmax = 100.0;
	for (int k = 0; k < 3; k++) {
		if (d[k] > 0.00001) {
			tmax = min(tmax, (1.0 - l) / d[k]);
		} else if (d[k] < -0.00001) {
			tmax = min(tmax, -l / d[k]);
		}
	}
	return vec3(l) + d * min(t, max(tmax, 1.0));
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float i = dot(rgb, LUMA);
	vec2 px = 1.0 / max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float soft = 0.25 * (luma_at(UV + px * vec2(-0.5, -0.5)) + luma_at(UV + px * vec2(0.5, -0.5)) + luma_at(UV + px * vec2(-0.5, 0.5)) + luma_at(UV + px * vec2(0.5, 0.5)));
	vec2 ab = cubic_decoded(ab_tex, UV);
	float edge_base = clamp(ab.x * soft + ab.y, 0.0, 1.0);
	float plain_base = clamp(cubic_decoded(stats_tex, UV).x, 0.0, 1.0);
	float s = clamp(strength, 0.0, 100.0) / 100.0;
	float base = mix(edge_base, plain_base, pick(HALO));
	float toned = tone(base, s);
	float shadow = 1.0 - smoothstep(0.06, 0.4, base);
	float sm = clamp(smoothing, 0.0, 100.0) / 100.0;
	float dk = clamp(detail, 0.0, 100.0) / 50.0;
	float skin = skin_mask(rgb) * clamp(keep_skin, 0.0, 100.0) / 100.0;
	float g_mid = 1.0 + s * pick(GAIN) * dk;
	g_mid = mix(g_mid, 1.0 + (g_mid - 1.0) * 0.35, skin);
	g_mid = mix(g_mid, 1.0, sm * shadow * 0.6);
	float g_fine = 1.0 + s * pick(GRIT) * dk;
	g_fine = mix(g_fine, 1.0, skin * 0.8);
	g_fine = mix(g_fine, 0.15, sm * shadow);
	float fine = i - soft;
	fine *= smoothstep(0.0, 0.004 + 0.014 * sm * shadow, abs(fine));
	float target = toned + g_mid * (soft - base) + g_fine * fine;
	float delta = soft_into(target - i, i);
	vec3 outc = apply_luma(rgb, i, delta);
	float sat = s * pick(COLOUR) + clamp(saturation, -100.0, 100.0) / 100.0 * 0.8;
	sat = mix(sat, min(sat, 0.05), skin);
	outc = push_colour(clamp(outc, 0.0, 1.0), sat);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
