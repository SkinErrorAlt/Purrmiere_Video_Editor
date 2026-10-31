shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int style = 0;
uniform float width : hint_range(0.02, 0.3) = 0.08;
uniform vec4 frame_colour : source_color = vec4(0.12, 0.1, 0.09, 1.0);
uniform vec4 mat_colour : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform int picture = 0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec4 insets(int s, float w) {
	if (s == 0) {
		return vec4(w);
	}
	if (s == 3) {
		return vec4(w * 0.6, w * 0.6, w * 0.6, w * 2.2);
	}
	if (s == 4) {
		return vec4(w * 0.3, w * 1.3, w * 0.3, w * 1.3);
	}
	return vec4(w);
}

void fragment() {
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 k = vec2(asp, 1.0);
	vec2 q = UV * k;
	float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
	float w = clamp(width, 0.02, 0.3) * min(asp, 1.0);
	vec4 ins = insets(style, w);
	vec2 lo = vec2(ins.x, ins.y);
	vec2 hi = vec2(asp - ins.z, 1.0 - ins.w);
	vec2 in_size = max(hi - lo, vec2(0.01));
	vec2 local = (q - lo) / in_size;
	vec4 pic;
	if (picture == 2) {
		pic = texture(effect_tex, UV);
	} else {
		float own = asp;
		float want = in_size.x / in_size.y;
		if (picture == 0) {
			vec2 crop = want < own ? vec2(want / own, 1.0) : vec2(1.0, own / want);
			pic = texture(effect_tex, (vec2(1.0) - crop) * 0.5 + clamp(local, vec2(0.0), vec2(1.0)) * crop);
		} else {
			vec2 shown = want > own ? vec2(own / want, 1.0) : vec2(1.0, want / own);
			vec2 f = (local - (vec2(1.0) - shown) * 0.5) / shown;
			vec2 inside = step(vec2(0.0), f) * step(f, vec2(1.0));
			pic = texture(effect_tex, clamp(f, vec2(0.0), vec2(1.0))) * inside.x * inside.y;
			pic = pic + vec4(mat_colour.rgb, 1.0) * (1.0 - pic.a);
		}
	}
	vec2 ic = (lo + hi) * 0.5;
	float inner_d = box_sd(q - ic, in_size * 0.5, 0.0);
	float in_cov = clamp(0.5 - inner_d / aa, 0.0, 1.0);
	float edge_in = max(-inner_d, 0.0);
	float sh = clamp(shadow, 0.0, 1.0) * 0.55 * exp(-edge_in / max(w * 0.12, 0.002));
	float top_left = clamp(0.5 + 0.5 * ((q.y - lo.y) < (q.x - lo.x) ? 1.0 : 0.6), 0.0, 1.0);
	pic.rgb *= 1.0 - sh * top_left;
	float dl = q.x;
	float dt = q.y;
	float dr = asp - q.x;
	float db = 1.0 - q.y;
	vec4 band = vec4(dl / max(ins.x, 0.0001), dt / max(ins.y, 0.0001), dr / max(ins.z, 0.0001), db / max(ins.w, 0.0001));
	float m = min(min(band.x, band.y), min(band.z, band.w));
	int side = m == band.x ? 0 : (m == band.y ? 1 : (m == band.z ? 2 : 3));
	float across = clamp(m, 0.0, 1.0);
	float along = side == 1 || side == 3 ? q.x : q.y;
	float light = side == 0 || side == 1 ? 1.12 : 0.82;
	vec3 frame_rgb = frame_colour.rgb;
	float frame_a = 1.0;
	if (style == 0) {
		float outer = 0.3;
		if (across < outer) {
			float v = across / outer;
			frame_rgb = frame_colour.rgb * light * (0.85 + 0.3 * sin(v * 3.14159));
		} else {
			frame_rgb = mat_colour.rgb;
			float bevel_w = 0.07;
			if (across > 1.0 - bevel_w) {
				frame_rgb = mat_colour.rgb * (side == 0 || side == 1 ? 0.8 : 1.08);
			}
			frame_rgb *= 1.0 - 0.18 * exp(-(across - outer) * 22.0);
		}
	} else if (style == 1) {
		vec3 light_wood = mix(vec3(0.62, 0.42, 0.24), frame_colour.rgb, 0.3);
		vec3 dark_wood = light_wood * 0.55;
		float grain = vnoise(vec2(along * 90.0, across * 3.0 + float(side) * 7.0)) * 0.6 + vnoise(vec2(along * 14.0 + float(side) * 3.0, across * 1.5)) * 0.4;
		float rings = 0.5 + 0.5 * sin(grain * 18.0 + along * 6.0);
		frame_rgb = mix(dark_wood, light_wood, rings) * light * (0.78 + 0.3 * sin(across * 3.14159));
	} else if (style == 2) {
		vec3 gold = vec3(0.86, 0.68, 0.3);
		float profile = 0.65 + 0.35 * sin(across * 3.14159 * 3.0 + 0.4);
		float ornament = 0.9 + 0.1 * sin(along * 260.0) * smoothstep(0.35, 0.5, across) * (1.0 - smoothstep(0.6, 0.75, across));
		frame_rgb = gold * light * profile * ornament + vec3(0.25, 0.2, 0.1) * pow(max(profile - 0.8, 0.0) * 4.0, 2.0);
	} else if (style == 3) {
		frame_rgb = mat_colour.rgb * (0.94 + 0.06 * vnoise(q * 400.0));
	} else if (style == 4) {
		frame_rgb = vec3(0.05, 0.045, 0.04);
		if (side == 1 || side == 3) {
			float band_h = side == 1 ? ins.y : ins.w;
			float cy = side == 1 ? band_h * 0.5 : 1.0 - band_h * 0.5;
			float pitch = band_h * 1.25;
			float hx = (fract(q.x / pitch) - 0.5) * pitch;
			float hole = box_sd(vec2(hx, q.y - cy), vec2(pitch * 0.2, band_h * 0.22), band_h * 0.06);
			frame_a = clamp(0.5 + hole / aa, 0.0, 1.0);
		}
	}
	vec4 frame_c = vec4(clamp(frame_rgb, 0.0, 1.0), 1.0) * frame_a * frame_colour.a;
	if (style == 0 || style == 3) {
		frame_c = vec4(clamp(frame_rgb, 0.0, 1.0), 1.0) * frame_a;
	}
	COLOR = mix(frame_c, pic, in_cov);
}
