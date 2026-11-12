shader_type canvas_item;
render_mode blend_disabled;

uniform float temperature : hint_range(-100.0, 100.0) = 0.0;
uniform float tint : hint_range(-100.0, 100.0) = 0.0;
uniform float exposure : hint_range(-5.0, 5.0) = 0.0;
uniform float contrast : hint_range(-100.0, 100.0) = 0.0;
uniform float highlights : hint_range(-100.0, 100.0) = 0.0;
uniform float shadows : hint_range(-100.0, 100.0) = 0.0;
uniform float whites : hint_range(-100.0, 100.0) = 0.0;
uniform float blacks : hint_range(-100.0, 100.0) = 0.0;
uniform float saturation : hint_range(0.0, 200.0) = 100.0;
uniform float vibrance : hint_range(-100.0, 100.0) = 0.0;
uniform float faded_film : hint_range(0.0, 100.0) = 0.0;
uniform float sharpen : hint_range(0.0, 100.0) = 0.0;
uniform float shadow_tint_hue : hint_range(0.0, 360.0) = 200.0;
uniform float shadow_tint : hint_range(0.0, 100.0) = 0.0;
uniform float highlight_tint_hue : hint_range(0.0, 360.0) = 40.0;
uniform float highlight_tint : hint_range(0.0, 100.0) = 0.0;
uniform float tint_balance : hint_range(-100.0, 100.0) = 0.0;
uniform sampler2D master : filter_linear, repeat_disable;
uniform sampler2D red : filter_linear, repeat_disable;
uniform sampler2D green : filter_linear, repeat_disable;
uniform sampler2D blue : filter_linear, repeat_disable;
uniform sampler2D hue_vs_sat : filter_linear, repeat_disable;
uniform sampler2D hue_vs_hue : filter_linear, repeat_disable;
uniform sampler2D hue_vs_luma : filter_linear, repeat_disable;
uniform sampler2D luma_vs_sat : filter_linear, repeat_disable;
uniform float shadows_hue : hint_range(0.0, 360.0) = 0.0;
uniform float shadows_amount : hint_range(0.0, 100.0) = 0.0;
uniform float shadows_level : hint_range(-100.0, 100.0) = 0.0;
uniform float midtones_hue : hint_range(0.0, 360.0) = 0.0;
uniform float midtones_amount : hint_range(0.0, 100.0) = 0.0;
uniform float midtones_level : hint_range(-100.0, 100.0) = 0.0;
uniform float highlights_hue : hint_range(0.0, 360.0) = 0.0;
uniform float highlights_amount : hint_range(0.0, 100.0) = 0.0;
uniform float highlights_level : hint_range(-100.0, 100.0) = 0.0;
uniform bool key_on = false;
uniform float key_hue : hint_range(0.0, 360.0) = 25.0;
uniform float key_hue_width : hint_range(0.0, 180.0) = 25.0;
uniform float key_sat_low : hint_range(0.0, 100.0) = 15.0;
uniform float key_sat_high : hint_range(0.0, 100.0) = 100.0;
uniform float key_luma_low : hint_range(0.0, 100.0) = 5.0;
uniform float key_luma_high : hint_range(0.0, 100.0) = 95.0;
uniform float key_softness : hint_range(0.0, 100.0) = 30.0;
uniform float key_denoise : hint_range(0.0, 100.0) = 20.0;
uniform bool key_invert = false;
uniform bool key_show = false;
uniform float key_hue_shift : hint_range(-180.0, 180.0) = 0.0;
uniform float key_saturation : hint_range(0.0, 200.0) = 100.0;
uniform float key_exposure : hint_range(-3.0, 3.0) = 0.0;
uniform float key_temperature : hint_range(-100.0, 100.0) = 0.0;
uniform float key_tint : hint_range(-100.0, 100.0) = 0.0;
uniform float vignette : hint_range(-3.0, 3.0) = 0.0;
uniform float vignette_midpoint : hint_range(0.0, 100.0) = 50.0;
uniform float vignette_roundness : hint_range(-100.0, 100.0) = 0.0;
uniform float vignette_feather : hint_range(0.0, 100.0) = 50.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float lut(sampler2D t, float x) {
	return texture(t, vec2(clamp(x, 0.0, 1.0) * (255.0 / 256.0) + 0.5 / 256.0, 0.5)).r;
}

float centred(sampler2D t, float x) {
	float d = lut(t, x) - 0.5;
	return abs(d) < 0.003 ? 0.0 : d;
}

vec3 to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = max(c, vec3(0.0));
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 rgb_to_hsl(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float l = (mx + mn) * 0.5;
	float d = mx - mn;
	float h = 0.0;
	float s = 0.0;
	if (d > 0.00001) {
		s = d / max(1.0 - abs(2.0 * l - 1.0), 0.00001);
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		h /= 6.0;
	}
	return vec3(h, clamp(s, 0.0, 1.0), l);
}

vec3 hsl_to_rgb(vec3 hsl) {
	vec3 k = mod(vec3(0.0, 8.0, 4.0) + hsl.x * 12.0, 12.0);
	float amp = hsl.y * min(hsl.z, 1.0 - hsl.z);
	return vec3(hsl.z) - amp * max(vec3(-1.0), min(min(k - 3.0, 9.0 - k), vec3(1.0)));
}

vec3 hue_push(float hue_deg, float amount) {
	vec3 h = hsl_to_rgb(vec3(fract(hue_deg / 360.0), 1.0, 0.5));
	return (h - vec3(dot(h, LUMA))) * amount;
}

vec3 balance(vec3 lin, float temp, float tnt) {
	float t = temp / 100.0;
	float n = tnt / 100.0;
	vec3 g = exp2(vec3(t * 0.7 + n * 0.3, -n * 0.6, -t * 0.7 + n * 0.3));
	return lin * g / dot(g, LUMA);
}

float band(float x, float lo, float hi, float soft) {
	float s = max(soft, 0.001);
	return smoothstep(lo - s, lo, x) * (1.0 - smoothstep(hi, hi + s, x));
}

float key_of(vec3 rgb) {
	vec3 hsl = rgb_to_hsl(clamp(rgb, 0.0, 1.0));
	float dh = abs(mod(hsl.x * 360.0 - key_hue + 180.0, 360.0) - 180.0);
	float soft = key_softness / 100.0;
	float w_hue = 1.0 - smoothstep(key_hue_width, key_hue_width + max(soft * 60.0, 0.5), dh);
	float w_sat = band(hsl.y, key_sat_low / 100.0, key_sat_high / 100.0, soft * 0.25);
	float w_luma = band(dot(rgb, LUMA), key_luma_low / 100.0, key_luma_high / 100.0, soft * 0.25);
	return clamp(w_hue * w_sat * w_luma, 0.0, 1.0);
}

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 orig = clamp(unpremul(src), 0.0, 1.0);
	vec3 rgb = orig;
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));

	if (sharpen > 0.0) {
		vec3 n = unpremul(texture(TEXTURE, UV + vec2(px.x, 0.0)));
		n += unpremul(texture(TEXTURE, UV - vec2(px.x, 0.0)));
		n += unpremul(texture(TEXTURE, UV + vec2(0.0, px.y)));
		n += unpremul(texture(TEXTURE, UV - vec2(0.0, px.y)));
		vec3 detail = rgb - n * 0.25;
		float edge = clamp(1.0 - length(detail) * 4.0, 0.25, 1.0);
		rgb = clamp(rgb + detail * (sharpen / 100.0) * 2.0 * edge, 0.0, 1.0);
	}

	vec3 lin = to_linear(rgb);
	lin = balance(lin, temperature, tint);
	lin *= exp2(exposure);
	float y_lin = max(dot(lin, LUMA), 0.00001);
	float yl = log2(y_lin / 0.18);
	float c_mul = contrast >= 0.0 ? 1.0 + contrast / 100.0 * 0.9 : 1.0 + contrast / 100.0 * 0.65;
	float yl2 = yl * c_mul;
	float roll = 6.0;
	yl2 = clamp(yl2, -roll * 1.5, roll);
	lin *= exp2(yl2 - yl);
	rgb = to_display(lin);
	float hdr = max(rgb.r, max(rgb.g, rgb.b));
	if (hdr > 1.0) {
		float k = 1.0 - exp(-(hdr - 1.0) * 1.6);
		rgb = mix(rgb / hdr, vec3(1.0), k * 0.65);
	}

	float y = clamp(dot(rgb, LUMA), 0.0, 1.0);
	float w_sh = pow(1.0 - smoothstep(0.0, 0.6, y), 1.6);
	float w_hi = pow(smoothstep(0.4, 1.0, y), 1.6);
	float y2 = y;
	y2 += shadows / 100.0 * 0.35 * w_sh * (1.0 - y);
	y2 += highlights / 100.0 * 0.35 * w_hi * (highlights < 0.0 ? y : 1.0 - y);
	float bp = -blacks / 100.0 * 0.12;
	float wp = 1.0 - whites / 100.0 * 0.15;
	y2 = (y2 - bp) / max(wp - bp, 0.05);
	y2 = max(y2, 0.0);
	if (y > 0.0001) {
		float ratio = y2 / y;
		vec3 scaled = rgb * ratio;
		vec3 lifted = rgb + vec3(y2 - y);
		rgb = mix(lifted, scaled, smoothstep(0.02, 0.15, y));
	} else {
		rgb = vec3(y2);
	}

	float sat_in = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
	vec3 hsl0 = rgb_to_hsl(clamp(rgb, 0.0, 1.0));
	float skin = 1.0 - smoothstep(10.0, 35.0, abs(mod(hsl0.x * 360.0 - 25.0 + 180.0, 360.0) - 180.0));
	float vib = vibrance / 100.0;
	float vib_w = vib >= 0.0 ? vib * (1.0 - clamp(sat_in * 1.4, 0.0, 1.0)) * (1.0 - skin * 0.6) : vib;
	float sat_total = saturation / 100.0 * (1.0 + vib_w);
	float yy = dot(rgb, LUMA);
	rgb = vec3(yy) + (rgb - vec3(yy)) * max(sat_total, 0.0);

	if (faded_film > 0.0) {
		float f = faded_film / 100.0;
		vec3 toe = vec3(0.09) + rgb * 0.91;
		vec3 faded = mix(rgb, toe, smoothstep(0.65, 0.0, rgb) * 0.9);
		faded = mix(faded, vec3(dot(faded, LUMA)), 0.12);
		rgb = mix(rgb, faded, f);
	}
	float yt = clamp(dot(rgb, LUMA), 0.0, 1.0);
	float pivot = 0.5 + tint_balance / 100.0 * 0.35;
	float ws = 1.0 - smoothstep(0.0, pivot * 1.4, yt);
	float wh = smoothstep(pivot * 0.6, 1.0, yt);
	rgb += hue_push(shadow_tint_hue, shadow_tint / 100.0 * 0.35) * ws;
	rgb += hue_push(highlight_tint_hue, highlight_tint / 100.0 * 0.35) * wh;

	rgb = clamp(rgb, 0.0, 1.0);
	rgb = vec3(lut(red, rgb.r), lut(green, rgb.g), lut(blue, rgb.b));
	rgb = vec3(lut(master, rgb.r), lut(master, rgb.g), lut(master, rgb.b));
	vec3 hsl = rgb_to_hsl(rgb);
	float yc = dot(rgb, LUMA);
	float turn = centred(hue_vs_hue, hsl.x);
	float smul = (1.0 + 2.0 * centred(hue_vs_sat, hsl.x)) * (1.0 + 2.0 * centred(luma_vs_sat, yc));
	vec3 moved = hsl_to_rgb(vec3(fract(hsl.x + turn), clamp(hsl.y * smul, 0.0, 1.0), hsl.z));
	moved += vec3(yc - dot(moved, LUMA));
	float chroma = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
	moved += vec3(centred(hue_vs_luma, hsl.x) * smoothstep(0.02, 0.25, chroma));
	rgb = clamp(moved, 0.0, 1.0);

	vec3 lift = hue_push(shadows_hue, shadows_amount / 100.0 * 0.6) + vec3(shadows_level / 100.0 * 0.25);
	vec3 gamma_v = hue_push(midtones_hue, midtones_amount / 100.0 * 0.8) + vec3(midtones_level / 100.0 * 0.6);
	vec3 gain = hue_push(highlights_hue, highlights_amount / 100.0 * 0.8) + vec3(highlights_level / 100.0 * 0.6);
	rgb = rgb + lift * (1.0 - rgb);
	rgb = clamp(rgb, 0.0, 1.0);
	rgb = pow(rgb, exp2(-gamma_v * 1.2));
	rgb = rgb * (1.0 + gain);
	rgb = clamp(rgb, 0.0, 1.0);

	if (key_on) {
		float m = key_of(orig);
		if (key_denoise > 0.0) {
			float r = key_denoise / 100.0 * 4.0;
			float acc = m;
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(px.x, px.y) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(-px.x, px.y) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(px.x, -px.y) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(-px.x, -px.y) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(-px.x * 2.0, 0.0) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(0.0, px.y * 2.0) * r)), 0.0, 1.0));
			acc += key_of(clamp(unpremul(texture(TEXTURE, UV + vec2(0.0, -px.y * 2.0) * r)), 0.0, 1.0));
			m = acc / 9.0;
		}
		if (key_invert) {
			m = 1.0 - m;
		}
		vec3 k = to_linear(rgb);
		k = balance(k, key_temperature, key_tint) * exp2(key_exposure);
		vec3 kd = clamp(to_display(k), 0.0, 1.0);
		vec3 khsl = rgb_to_hsl(kd);
		vec3 kc = hsl_to_rgb(vec3(fract(khsl.x + key_hue_shift / 360.0), clamp(khsl.y * key_saturation / 100.0, 0.0, 1.0), khsl.z));
		rgb = mix(rgb, kc, m);
		if (key_show) {
			rgb = mix(vec3(dot(orig, LUMA)) * 0.25, rgb, m);
		}
	}

	if (abs(vignette) > 0.0001) {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 d = (UV - 0.5) * 2.0;
		float round_t = vignette_roundness / 100.0;
		d.x *= mix(1.0, asp, clamp(round_t, 0.0, 1.0));
		float shape = round_t < 0.0 ? mix(2.0, 8.0, -round_t) : 2.0;
		float r = pow(pow(abs(d.x), shape) + pow(abs(d.y), shape), 1.0 / shape);
		float mid = mix(0.2, 1.3, vignette_midpoint / 100.0);
		float feather = mix(0.02, 1.2, vignette_feather / 100.0);
		float v = smoothstep(mid - feather * 0.5, mid + feather * 0.5, r);
		if (vignette < 0.0) {
			vec3 lin_v = to_linear(rgb) * exp2(vignette * v * 1.1);
			rgb = to_display(lin_v);
		} else {
			rgb = mix(rgb, vec3(1.0) - (vec3(1.0) - rgb) * exp2(-vignette * 0.9), v);
		}
	}

	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
