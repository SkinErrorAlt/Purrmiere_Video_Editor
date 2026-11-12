shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float time = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float fov : hint_range(60.0, 300.0) = 230.0;
uniform float spread : hint_range(0.3, 3.0) = 1.0;
uniform float waves : hint_range(0.0, 1.0) = 0.25;
uniform float wave_size : hint_range(0.05, 10.0) = 1.2;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float depth : hint_range(0.1, 30.0) = 2.0;
uniform float murk : hint_range(0.0, 1.0) = 0.3;
uniform float rainbow : hint_range(0.0, 8.0) = 1.0;
uniform vec4 water_colour : source_color = vec4(0.02, 0.2, 0.26, 1.0);
uniform int seed = 0;

float hash11(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

vec3 to_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 to_srgb(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

vec2 wave_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	float base = float(seed) * 13.17;
	for (int k = 0; k < 8; k++) {
		float fk = float(k);
		float a = hash11(base + fk * 3.1) * 6.2831853;
		float lam = wave_size * mix(0.35, 1.8, hash11(base + fk * 7.7));
		vec2 dir = vec2(cos(a), sin(a));
		float kk = 6.2831853 / lam;
		float w = sqrt(9.81 * kk);
		float ph = hash11(base + fk * 5.3) * 6.2831853;
		s += dir * cos(dot(dir, p) * kk - w * t + ph) * (0.3 + 0.7 * hash11(base + fk * 9.1));
	}
	return s * waves * 0.09;
}

vec3 fish_dir(vec2 q, float f) {
	float r = length(q);
	float th = r / f;
	vec2 a = r > 1e-6 ? q / r : vec2(0.0);
	return vec3(a * sin(th), cos(th));
}

float fresnel_out(float cosi, float eta) {
	float sint2 = eta * eta * (1.0 - cosi * cosi);
	if (sint2 >= 1.0) {
		return 1.0;
	}
	float cost = sqrt(1.0 - sint2);
	float rs = (eta * cosi - cost) / (eta * cosi + cost);
	float rp = (cosi - eta * cost) / (cosi + eta * cost);
	return clamp(0.5 * (rs * rs + rp * rp), 0.0, 1.0);
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 asp = vec2(aspect, 1.0);
	float f = aspect * 0.5 / (radians(fov) * 0.5);
	vec3 d = fish_dir((UV - 0.5) * asp, f);
	vec3 Z = fish_dir((centre - 0.5) * asp, f);
	vec3 ex = normalize(vec3(1.0, 0.0, 0.0) - Z * Z.x);
	vec3 ey = normalize(cross(Z, ex));
	vec3 dw = vec3(dot(d, ex), dot(d, ey), dot(d, Z));
	vec3 deep = to_lin(water_colour.rgb);
	vec3 col;
	float alpha = texture(TEXTURE, UV).a;
	float up = clamp(dw.z, -1.0, 1.0);
	vec3 haze = deep * mix(0.55, 1.25, smoothstep(0.0, 0.9, up));
	if (dw.z < 0.002) {
		col = mix(deep * 0.18, haze, smoothstep(-0.9, 0.002, up));
	} else {
		vec2 P = dw.xy / dw.z * depth;
		vec2 sl = wave_slope(P, time * speed);
		vec3 n = normalize(vec3(-sl, 1.0));
		float cosi = clamp(dot(dw, n), 0.0, 1.0);
		vec3 offs = vec3(-0.0025, 0.0, 0.0055) * rainbow;
		vec3 sky = vec3(0.0);
		vec3 refl = vec3(0.0);
		for (int c = 0; c < 3; c++) {
			float eta = 1.3345 + offs[c];
			vec3 t = refract(dw, -n, eta);
			float R = fresnel_out(cosi, eta);
			float sv = 0.0;
			if (dot(t, t) > 1e-6) {
				float th = acos(clamp(t.z, -1.0, 1.0));
				vec2 az = normalize(t.xy + vec2(1e-6, 0.0));
				vec2 uv = 0.5 + az * (th / 1.5707963) * 0.5 / spread;
				uv = clamp(uv, vec2(0.0), vec2(1.0));
				sv = to_lin(texture(TEXTURE, uv).rgb)[c];
			}
			sky[c] = sv * (1.0 - R);
			refl[c] = R;
		}
		vec3 r = reflect(dw, n);
		float down = clamp(-r.z, 0.0, 1.0);
		float ripple = 1.0 + 1.2 * (sl.x * 0.6 + sl.y * 0.8);
		vec3 deep_refl = deep * mix(0.75, 0.12, down) * ripple;
		float path = depth / max(dw.z, 0.002);
		vec3 trans = exp(-path * murk * vec3(0.55, 0.12, 0.07));
		vec3 through = sky + refl * deep_refl;
		col = mix(haze, through, trans);
	}
	COLOR = vec4(to_srgb(col) * alpha, alpha);
}
