shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float exposure : hint_range(-1.0, 6.0) = 1.5;
uniform int balance = 0;
uniform int highlights = 0;
uniform float bloom : hint_range(0.0, 1.0) = 0.5;
uniform float smear : hint_range(0.0, 1.0) = 0.35;
uniform float fringe : hint_range(0.0, 1.0) = 0.5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_lin(vec3 v) {
	vec3 lo = v / 12.92;
	vec3 hi = pow((v + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(v, vec3(0.04045)));
}

vec3 to_srgb(vec3 v) {
	vec3 lo = v * 12.92;
	vec3 hi = 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(hi, lo, step(v, vec3(0.0031308)));
}

vec3 wb_gains(int b) {
	if (b == 1) {
		return vec3(1.35, 1.0, 2.7);
	}
	if (b == 2) {
		return vec3(1.7, 1.0, 2.1);
	}
	return vec3(2.0, 1.0, 1.5);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec4 s = texture(TEXTURE, UV);
	float col_here = -log(1.0 - min(s.r, 0.999)) / 4.0;
	float col_wide = 0.0;
	for (int i = 1; i <= 4; i++) {
		float dx = float(i) * 0.03;
		col_wide += -log(1.0 - min(texture(TEXTURE, vec2(UV.x + dx, UV.y)).r, 0.999)) / 4.0;
		col_wide += -log(1.0 - min(texture(TEXTURE, vec2(UV.x - dx, UV.y)).r, 0.999)) / 4.0;
	}
	col_wide /= 8.0;
	float col = max(col_here - col_wide, 0.0) + 0.12 * col_here;
	float bl = -log(1.0 - min(s.g, 0.999));
	vec3 gains = wb_gains(balance);
	vec3 raw = to_lin(clamp(rgb, 0.0, 1.0)) * exp2(exposure) / gains;
	float charge = bloom * bloom * bl * 1.4 + smear * col * 0.5;
	raw += vec3(charge);
	vec3 cap = vec3(1.0);
	if (highlights == 1) {
		cap = vec3(1.0, 0.84, 1.0);
	} else if (highlights == 2) {
		cap = vec3(0.8, 1.0, 1.0);
	}
	vec3 lin = min(raw * gains, cap);
	vec3 outc = to_srgb(lin);
	float clip_here = smoothstep(0.9, 1.0, max(raw.r * gains.r, max(raw.g, raw.b * gains.b)));
	float f = fringe * smoothstep(0.02, 0.45, s.b) * (1.0 - clip_here);
	if (f > 0.0) {
		float y = dot(outc, LUMA);
		float dark = 1.0 - smoothstep(0.1, 0.6, y);
		float k = clamp(f * dark * 1.1, 0.0, 1.0);
		vec3 purple = vec3(0.55, 0.12, 0.95) * max(y, 0.35) * 1.6;
		outc = mix(outc, max(outc, purple), k);
		outc.g *= 1.0 - 0.4 * k;
	}
	outc = clamp(outc, 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
