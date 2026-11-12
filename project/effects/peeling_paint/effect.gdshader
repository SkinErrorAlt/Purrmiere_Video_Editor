shader_type canvas_item;
render_mode blend_disabled;

uniform float peel : hint_range(0.0, 1.0) = 0.5;
uniform float grow_time : hint_range(0.0, 30.0) = 0.0;
uniform float flake_size : hint_range(10.0, 400.0) = 80.0;
uniform float curl : hint_range(0.0, 1.0) = 0.6;
uniform int wall : hint_range(0, 3) = 0;
uniform vec4 under : source_color = vec4(0.36, 0.55, 0.52, 1.0);
uniform float weather : hint_range(0.0, 1.0) = 0.3;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 289.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / 0.9375;
}

float flake_start(vec2 id, vec2 so) {
	float h = hash12(mod(id, 289.0) + 0.37);
	float cluster = fbm((id + so) * 0.17);
	return mix(h, cluster * 1.25 - 0.1, 0.72) * 1.05 - 0.22;
}

vec4 paint_state(vec2 pix, float fs, vec2 so, float p) {
	vec2 q = pix / fs + so;
	q += (vec2(fbm(q * 0.7), fbm(q * 0.7 + vec2(3.3, 8.1))) - 0.5) * 0.7;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = vec2(0.0);
	vec2 c1 = vec2(0.0);
	vec2 c2 = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(mod(i + g, 289.0)) * 0.85 + 0.075;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				c2 = c1;
				d1 = d;
				c1 = r;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
				c2 = r;
			}
		}
	}
	float e = dot(0.5 * (c1 + c2), normalize(c2 - c1));
	e += (vnoise(q * 9.0) - 0.5) * 0.04 + (vnoise(q * 23.0) - 0.5) * 0.02;
	e = max(e, 0.0);
	vec2 id2;
	id2 = floor(q + c2);
	float s1 = flake_start(id, so);
	float s2 = flake_start(id2, so);
	const float LIFE = 0.28;
	float f1 = step(s1 + LIFE, p);
	float f2 = step(s2 + LIFE, p);
	float aa = smoothstep(0.0, 0.02, e);
	float fallen = mix(0.5 * (f1 + f2), f1, aa);
	float local1 = clamp((p - s1) / LIFE, 0.0, 1.0);
	float own = local1 * local1 * smoothstep(0.08 + 0.4 * local1, 0.0, e);
	float nb = f2 * smoothstep(0.2, 0.0, e) * 0.85;
	float lift = max(own, nb) * (1.0 - f1);
	float crack = (1.0 - smoothstep(0.0, 0.016, e)) * smoothstep(min(s1, s2) - 0.1, min(s1, s2) + 0.05, p) * (1.0 - f1);
	float tip = smoothstep(0.035, 0.0, e) * smoothstep(0.35, 0.7, lift);
	float on = smoothstep(0.0, 0.05, p);
	return vec4(fallen * step(0.0005, p), lift * on, crack * on, tip * on);
}

vec3 wall_colour(vec2 pix, float ps, vec2 so) {
	float n1 = fbm(pix / max(90.0 * ps, 1.0) + so);
	float n2 = vnoise(pix / max(2.0 * ps, 1.0) + so);
	float n3 = fbm(pix / max(12.0 * ps, 1.0) + so * 2.0);
	if (wall == 1) {
		vec3 c = vec3(0.56, 0.55, 0.52) * (0.85 + 0.25 * n1) * (0.92 + 0.12 * n2);
		float pore = step(0.86, vnoise(pix / max(3.5 * ps, 1.0) + so * 3.0));
		return c * (1.0 - pore * 0.45) * (0.95 + 0.1 * n3);
	} else if (wall == 2) {
		float grain = sin(pix.y / max(3.0 * ps, 1.0) + fbm(pix / max(40.0 * ps, 1.0) * vec2(0.1, 1.0) + so) * 18.0);
		vec3 c = mix(vec3(0.45, 0.33, 0.22), vec3(0.6, 0.47, 0.33), 0.5 + 0.5 * grain);
		return c * (0.85 + 0.25 * n1) * (0.95 + 0.08 * n2);
	} else if (wall == 3) {
		vec3 c = under.rgb * (0.88 + 0.2 * n1) * (0.95 + 0.08 * n2);
		return mix(c, c * 0.85 + 0.1, smoothstep(0.55, 0.8, n3) * 0.4);
	}
	vec3 c = vec3(0.86, 0.84, 0.78) * (0.86 + 0.2 * n1) * (0.93 + 0.1 * n2);
	c = mix(c, c * vec3(0.92, 0.86, 0.72), smoothstep(0.55, 0.85, n3) * 0.5);
	return c;
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 so = vec2(sk * 0.571 + 7.0, sk * 0.833 + 19.0);
	float p = clamp(peel, 0.0, 1.0);
	if (grow_time > 0.0001) {
		p *= clamp(max(clip_time, 0.0) / grow_time, 0.0, 1.0);
	}
	float fs = max(flake_size * ps, 3.0);
	float la = radians(light_angle);
	vec2 L = vec2(cos(la), -sin(la));
	vec4 st = paint_state(pix, fs, so, p);
	float lift = st.y * curl;
	vec2 shift = -L * lift * lift * 3.0 * ps;
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;
	vec4 sc = texture(TEXTURE, clamp((pix + shift) / sz, vec2(0.0), vec2(1.0)));
	vec3 pic = sc.a > 0.0001 ? sc.rgb / sc.a : vec3(0.0);
	float tooth = fbm(pix / max(6.0 * ps, 1.0) * vec2(1.0, 0.35) + so);
	vec3 paint = mix(pic, mix(pic, vec3(dot(pic, LUMA)), 0.3) * 0.85 + 0.12, weather * 0.6);
	paint *= 1.0 + (tooth - 0.5) * 0.1 * weather;
	paint *= 1.0 - st.z * 0.45 * (1.0 - st.x);
	vec2 gl = vec2(dFdx(lift), dFdy(lift));
	float facing = dot(-gl / max(1.5 * ps, 0.001), L);
	paint *= clamp(1.0 + facing * 3.5, 0.55, 1.6);
	paint += vec3(0.18) * smoothstep(0.1, 0.5, facing) * lift;
	vec3 underside = vec3(0.88, 0.86, 0.8) * (0.9 + 0.1 * tooth);
	paint = mix(paint, underside * clamp(0.75 + facing * 2.0, 0.5, 1.2), st.w * curl * 0.8);
	vec3 wallc = wall_colour(pix, ps, so);
	wallc = mix(wallc, wallc * (0.75 + 0.35 * dot(pic, LUMA)), 0.25);
	float sh = 0.0;
	for (int i = 1; i <= 3; i++) {
		float dist = float(i) * 4.0 * ps * (0.6 + curl);
		vec4 o = paint_state(pix + L * dist, fs, so, p);
		float occ = o.y * curl * (1.0 - float(i) * 0.22) + (1.0 - o.x) * st.x * (i == 1 ? 0.55 : 0.2);
		sh = max(sh, occ);
	}
	sh = clamp(sh, 0.0, 1.0) * shadow;
	vec3 col = mix(paint, wallc, st.x);
	col *= 1.0 - sh * mix(0.35, 0.6, st.x) * (1.0 - lift);
	float rim = smoothstep(0.0, 0.5, st.x) * (1.0 - smoothstep(0.5, 1.0, st.x));
	col += vec3(0.12) * rim * max(dot(L, vec2(0.0, -1.0)), 0.3);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
