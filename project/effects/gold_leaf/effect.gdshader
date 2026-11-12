shader_type canvas_item;
render_mode blend_disabled;

uniform int gild = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.62;
uniform float sheet : hint_range(10.0, 300.0) = 130.0;
uniform float wrinkle : hint_range(0.0, 1.0) = 0.5;
uniform float losses : hint_range(0.0, 1.0) = 0.35;
uniform float light_angle : hint_range(-180.0, 180.0) = -60.0;
uniform float burnish : hint_range(0.0, 1.0) = 0.6;
uniform vec4 gold : source_color = vec4(0.83, 0.64, 0.28, 1.0);
uniform vec4 bole : source_color = vec4(0.55, 0.2, 0.13, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(11.3, 5.9);
		a *= 0.5;
	}
	return s;
}

float lum_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return dot(c.rgb / max(c.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
}

float gild_mask(sampler2D tex, vec2 uv, vec2 to_uv, vec2 p, vec2 so) {
	float l = 0.0;
	for (int i = 0; i < 5; i++) {
		float a = float(i) * 1.2566;
		l += lum_at(tex, uv + vec2(cos(a), sin(a)) * 2.5 * to_uv);
	}
	l *= 0.2;
	float rag = (fbm(p * 0.08 + so) - 0.5) * 0.06;
	float m;
	if (gild == 0) {
		m = smoothstep(threshold - 0.015, threshold + 0.015, l + rag);
	} else if (gild == 1) {
		m = 1.0 - smoothstep(threshold - 0.015, threshold + 0.015, l + rag);
	} else {
		m = 1.0;
	}
	return m;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 pic = base.rgb / max(base.a, 0.0001);
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * tex_size / ps;
	vec2 to_uv = ps / tex_size;
	vec2 so = vec2(float(seed) * 2.71, float(seed) * 6.11);
	float m = gild_mask(TEXTURE, UV, to_uv, p, so);
	float S = max(sheet, 4.0);
	vec2 pw = p + (vec2(fbm(p * 0.02 + so), fbm(p * 0.02 + so + 8.0)) - 0.5) * S * 0.12;
	float row = floor(pw.y / S);
	float rowoff = h12(vec2(row, 1.0) + so) * S;
	vec2 sp = vec2(pw.x + rowoff, pw.y);
	vec2 sid = floor(sp / S);
	vec2 sf = fract(sp / S);
	vec2 tilt = (h22(sid + so) - 0.5) * 0.22;
	float sheet_tone = 0.92 + 0.16 * h12(sid + so + 4.0);
	float wr1 = fbm(p * 0.018 + sid * 7.0 + so);
	float wr2 = fbm(p * 0.06 + so * 1.7);
	vec2 grad = vec2(dFdx(wr1 + wr2 * 0.25), dFdy(wr1 + wr2 * 0.25)) * 40.0 / max(ps, 0.25);
	float crease = 1.0 - smoothstep(0.0, 0.025, abs(fbm(p * 0.02 + sid * 3.3 + so) - 0.5));
	vec3 N = normalize(vec3(tilt + grad * wrinkle + crease * 0.2 * wrinkle * vec2(0.7, -0.7), 1.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 0.75));
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float spec = pow(clamp(dot(N, H), 0.0, 1.0), mix(14.0, 70.0, burnish));
	float diff = clamp(dot(N, L), 0.0, 1.0);
	vec2 refl = UV + N.xy * 0.18 + vec2(0.0, -0.05);
	float env = 0.0;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		env += lum_at(TEXTURE, refl + vec2(cos(a), sin(a)) * 0.06);
	}
	env /= 6.0;
	vec3 gdark = gold.rgb * vec3(0.42, 0.33, 0.2);
	vec3 glite = mix(gold.rgb, vec3(1.0, 0.95, 0.75), 0.6);
	float face = clamp(0.25 + 0.45 * diff + 0.35 * env, 0.0, 1.0);
	vec3 gcol = mix(gdark, gold.rgb, smoothstep(0.0, 0.6, face));
	gcol = mix(gcol, glite, smoothstep(0.6, 1.0, face));
	gcol *= sheet_tone;
	gcol += vec3(1.0, 0.93, 0.72) * spec * (0.6 + 0.8 * burnish);
	vec2 e = min(sf, 1.0 - sf) * S;
	float seam = (1.0 - smoothstep(0.3, 1.2, min(e.x, e.y))) * (0.4 + 0.6 * vnoise(p * 0.05 + so));
	float seam_lip = (1.0 - smoothstep(1.2, 4.0, min(e.x, e.y))) * (1.0 - seam);
	gcol *= 1.0 - seam * 0.16;
	gcol *= 1.0 + seam_lip * 0.1 * (diff - 0.3);
	float tear_n = fbm(p * 0.03 + so * 3.0);
	float edge_bias = 1.0 - smoothstep(0.0, 6.0, min(e.x, e.y));
	float loss = smoothstep(0.76, 0.78, tear_n + edge_bias * 0.22 + vnoise(p * 0.4 + so) * 0.04) * losses;
	float pin = step(0.9985 - losses * 0.002, h12(floor(p * 0.34) + so)) * losses;
	loss = max(loss, pin);
	vec3 bolec = bole.rgb * (0.85 + 0.25 * vnoise(p * 0.2 + so));
	gcol = mix(gcol, bolec, clamp(loss, 0.0, 1.0));
	float mx = 0.0;
	if (gild < 2 && outline > 0.0) {
		float mr = gild_mask(TEXTURE, UV + vec2(2.0, 0.0) * to_uv, to_uv, p, so);
		float ml = gild_mask(TEXTURE, UV - vec2(2.0, 0.0) * to_uv, to_uv, p, so);
		float mu = gild_mask(TEXTURE, UV + vec2(0.0, 2.0) * to_uv, to_uv, p, so);
		float md = gild_mask(TEXTURE, UV - vec2(0.0, 2.0) * to_uv, to_uv, p, so);
		mx = clamp(abs(mr - ml) + abs(mu - md), 0.0, 1.0);
	}
	float pl = dot(pic, vec3(0.2126, 0.7152, 0.0722));
	vec3 tempera = mix(pic, vec3(pl) * vec3(1.05, 0.95, 0.8), 0.18) * vec3(1.0, 0.96, 0.88);
	tempera *= 0.95 + 0.08 * vnoise(p * 0.3 + so);
	vec3 col = mix(tempera, gcol, m);
	col = mix(col, vec3(0.12, 0.07, 0.04), mx * outline * 0.85);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
