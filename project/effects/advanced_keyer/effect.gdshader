shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 key_colour : source_color = vec4(0.2, 0.7, 0.3, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.5;
uniform float pedestal : hint_range(0.0, 1.0) = 0.1;
uniform float transparency : hint_range(0.0, 1.0) = 0.5;
uniform float highlight : hint_range(0.0, 1.0) = 0.1;
uniform float shadow : hint_range(0.0, 1.0) = 0.3;
uniform float choke : hint_range(-10.0, 10.0) = 0.0;
uniform float soften : hint_range(0.0, 20.0) = 0.0;
uniform float contrast : hint_range(0.0, 1.0) = 0.0;
uniform float mid_point : hint_range(0.0, 1.0) = 0.5;
uniform float spill : hint_range(0.0, 1.0) = 0.6;
uniform int output_mode : hint_range(0, 2) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 key_mask(vec3 k) {
	if (k.g >= k.r && k.g >= k.b) {
		return vec3(0.0, 1.0, 0.0);
	}
	if (k.b >= k.r) {
		return vec3(0.0, 0.0, 1.0);
	}
	return vec3(1.0, 0.0, 0.0);
}

float excess(vec3 c, vec3 pm) {
	vec3 others = max(c, vec3(0.0)) * (vec3(1.0) - pm);
	return dot(c, pm) - max(others.r, max(others.g, others.b));
}

vec2 hue_plane(vec3 c) {
	return vec2(c.r - 0.5 * (c.g + c.b), 0.8660254 * (c.g - c.b));
}

float raw_matte(vec3 rgb, vec3 key, vec3 pm) {
	float kd = max(excess(key, pm), 0.05);
	float ex = excess(rgb, pm);
	float s = ex / kd;
	vec2 hc = hue_plane(rgb);
	vec2 hk = hue_plane(key);
	float lc = length(hc);
	float lk = length(hk);
	float cosang = (lc > 0.0001 && lk > 0.0001) ? dot(hc, hk) / (lc * lk) : 1.0;
	float limit = radians(mix(20.0, 80.0, tolerance));
	s *= smoothstep(cos(limit + 0.35), cos(limit), cosang);
	float kp = max(dot(key, pm), 0.05);
	float cp = max(dot(rgb, pm), 0.0001);
	float purity = (max(ex, 0.0) / cp) / (kd / kp);
	float plo = mix(0.2, 0.02, tolerance);
	s *= smoothstep(plo, plo + 0.25, purity);
	s *= mix(0.95, 1.6, tolerance);
	float rel = dot(rgb, LUMA) / max(dot(key, LUMA), 0.02);
	float hi = highlight * smoothstep(1.05, 1.8, rel);
	float sh = shadow * smoothstep(0.75, 0.15, rel);
	s *= (1.0 - hi) * (1.0 - sh);
	return 1.0 - clamp(s, 0.0, 1.0);
}

float cleaned(float raw) {
	float ped = pedestal * 0.5;
	float alpha = clamp((raw - ped) / max(1.0 - ped, 0.01), 0.0, 1.0);
	return pow(alpha, exp2((transparency - 0.5) * 4.0));
}

vec3 despill(vec3 c, vec3 pm, float amount) {
	float over = max(excess(c, pm), 0.0) * amount;
	vec3 outc = c - pm * over;
	return outc + vec3(over * dot(LUMA, pm));
}

vec3 foreground(vec3 rgb, float raw, vec3 key, vec3 pm) {
	vec3 prem = clamp(rgb - (1.0 - raw) * key, vec3(0.0), vec3(raw));
	vec3 unmixed = raw > 0.0001 ? prem / raw : vec3(0.0);
	vec3 fallback = despill(rgb, pm, 1.0);
	return mix(fallback, unmixed, smoothstep(0.02, 0.12, raw));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 key = clamp(key_colour.rgb, 0.0, 1.0);
	vec3 pm = key_mask(key);
	float raw = raw_matte(rgb, key, pm);
	vec3 own_fg = foreground(rgb, raw, key, pm);
	vec3 fg = own_fg;
	float alpha = cleaned(raw) * a;
	float reach = max(soften, abs(choke) * 1.6) * px_scale;
	if (reach >= 0.5) {
		vec2 px = 1.0 / max(tex_size, vec2(1.0));
		float sum = alpha;
		float wsum = 1.0;
		vec3 col_sum = fg * raw * raw;
		float col_w = raw * raw;
		for (int i = 0; i < 24; i++) {
			float fi = float(i) + 0.5;
			float rr = sqrt(fi / 24.0);
			float ang = fi * 2.3999632;
			vec2 off = vec2(cos(ang), sin(ang)) * rr * reach;
			vec4 s = texture(TEXTURE, clamp(UV + off * px, vec2(0.0), vec2(1.0)));
			vec3 srgb = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
			float sraw = raw_matte(srgb, key, pm);
			float w = 1.0 - 0.6 * rr * rr;
			sum += cleaned(sraw) * s.a * w;
			wsum += w;
			float cw = sraw * sraw * s.a * w;
			col_sum += foreground(srgb, sraw, key, pm) * cw;
			col_w += cw;
		}
		float blurred = sum / wsum;
		float shift = 0.64 * choke * px_scale / reach;
		float half_w = min(0.5, 0.5 * max(soften * px_scale, 0.6) / reach);
		float lo = clamp(0.5 + shift - half_w, 0.0, 0.999);
		float hi = clamp(0.5 + shift + half_w, lo + 0.001, 1.0);
		alpha = clamp((blurred - lo) / (hi - lo), 0.0, 1.0);
		vec3 near_fg = col_w > 0.0001 ? col_sum / col_w : fg;
		fg = mix(near_fg, own_fg, clamp(raw * 1.5, 0.0, 1.0));
	}
	float gain = 1.0 + contrast * 15.0;
	alpha = clamp((alpha - mid_point) * gain + mid_point, 0.0, 1.0);
	float matte = a > 0.0001 ? clamp(alpha / a, 0.0, 1.0) : 0.0;
	vec3 clean = clamp(despill(fg, pm, spill), 0.0, 1.0);
	if (output_mode == 1) {
		COLOR = vec4(vec3(matte * a), 1.0);
	} else if (output_mode == 2) {
		COLOR = vec4(clamp(despill(own_fg, pm, spill), 0.0, 1.0), 1.0);
	} else {
		float oa = clamp(matte * a, 0.0, 1.0);
		COLOR = vec4(clean * oa, oa);
	}
}
