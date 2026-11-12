shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int shape = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius = 0.3;
uniform float ior = 1.52;
uniform float dispersion = 0.4;
uniform float field = 3.0;
uniform float angle = 0.0;
uniform float rod_length = 2.0;
uniform float reflection = 0.5;
uniform float shine = 0.6;
uniform vec4 tint : source_color = vec4(0.94, 0.98, 0.97, 1.0);

vec2 mirror_uv(vec2 uv) {
	vec2 t = mod(uv, 2.0);
	return mix(t, 2.0 - t, step(1.0, t));
}

vec3 wl_rgb(float l) {
	float t1 = (l - 442.0) * ((l < 442.0) ? 0.0624 : 0.0374);
	float t2 = (l - 599.8) * ((l < 599.8) ? 0.0264 : 0.0323);
	float t3 = (l - 501.1) * ((l < 501.1) ? 0.0490 : 0.0382);
	float x = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3);
	float u1 = (l - 568.8) * ((l < 568.8) ? 0.0213 : 0.0247);
	float u2 = (l - 530.9) * ((l < 530.9) ? 0.0613 : 0.0322);
	float y = 0.821 * exp(-0.5 * u1 * u1) + 0.286 * exp(-0.5 * u2 * u2);
	float v1 = (l - 437.0) * ((l < 437.0) ? 0.0845 : 0.0278);
	float v2 = (l - 459.0) * ((l < 459.0) ? 0.0385 : 0.0725);
	float z = 1.217 * exp(-0.5 * v1 * v1) + 0.681 * exp(-0.5 * v2 * v2);
	vec3 rgb = vec3(3.2406 * x - 1.5372 * y - 0.4986 * z, -0.9689 * x + 1.8758 * y + 0.0415 * z, 0.0557 * x - 0.2040 * y + 1.0570 * z);
	return max(rgb, vec3(0.0));
}

float fresnel(float cosi, float n) {
	float r0 = (n - 1.0) / (n + 1.0);
	r0 *= r0;
	float k = 1.0 - clamp(cosi, 0.0, 1.0);
	return r0 + (1.0 - r0) * k * k * k * k * k;
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 asp = vec2(aspect, 1.0);
	float rad = max(radius, 0.001);
	vec2 p = (UV - centre) * asp / rad;
	float ca = cos(radians(angle));
	float sa = sin(radians(angle));
	vec2 q = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);
	float r = shape == 0 ? length(p) : abs(q.x);
	float half_len = rod_length * 0.5 / rad;
	float px = 1.5 / (tex_size.y * rad);
	float inside = 1.0 - smoothstep(1.0 - px, 1.0, r);
	if (shape == 1) {
		inside *= 1.0 - smoothstep(half_len - px, half_len, abs(q.y));
	}
	vec4 back = texture(TEXTURE, UV);
	if (inside <= 0.0) {
		COLOR = back;
	} else {
		float rr = min(r, 0.9995);
		vec3 n1;
		if (shape == 0) {
			n1 = vec3(p / max(r, 1e-5) * rr, sqrt(1.0 - rr * rr));
		} else {
			n1 = vec3(sign(q.x) * rr, 0.0, sqrt(1.0 - rr * rr));
		}
		vec3 d0 = vec3(0.0, 0.0, -1.0);
		float B = dispersion * 0.02;
		vec4 acc = vec4(0.0);
		vec3 wsum = vec3(0.0);
		float chord = 0.0;
		for (int k = 0; k < 9; k++) {
			float lam = 410.0 + float(k) * 34.0;
			float lu = lam * 0.001;
			float n = ior + B * (1.0 / (lu * lu) - 1.0 / (0.5876 * 0.5876));
			vec3 t1 = refract(d0, n1, 1.0 / n);
			float t = -2.0 * dot(n1, t1);
			vec3 p2 = n1 + t1 * t;
			vec3 t2 = refract(t1, -p2, n);
			if (dot(t2, t2) < 1e-6) {
				t2 = reflect(t1, -p2);
			}
			chord = t;
			vec2 hit;
			if (t2.z < -1e-4) {
				float s = (-field - p2.z) / t2.z;
				hit = p2.xy + t2.xy * s;
			} else {
				hit = p2.xy + normalize(t2.xy + 1e-5) * field * 4.0;
			}
			vec2 hq = hit;
			if (shape == 1) {
				hq = vec2(hit.x, q.y);
				hq = vec2(ca * hq.x - sa * hq.y, sa * hq.x + ca * hq.y);
			}
			vec2 uv = centre + hq * rad / asp;
			vec4 c = texture(effect_tex, mirror_uv(uv));
			vec3 w = wl_rgb(lam);
			acc += vec4(c.rgb * w, c.a * (w.r + w.g + w.b) / 3.0);
			wsum += w;
		}
		vec3 refr = acc.rgb / max(wsum, vec3(1e-4));
		float ra = acc.a / max((wsum.r + wsum.g + wsum.b) / 3.0, 1e-4);
		float cosi = n1.z;
		float fr = fresnel(cosi, ior);
		vec3 absorb = pow(max(tint.rgb, vec3(0.01)), vec3(chord * 0.5));
		vec3 refl_dir = reflect(d0, n1);
		vec2 env_uv = centre + refl_dir.xy * vec2(0.5 / aspect, 0.5) * 1.6;
		vec3 env = texture(TEXTURE, mirror_uv(env_uv)).rgb;
		vec3 L = normalize(vec3(-0.45, -0.6, 0.66));
		float spec = pow(max(dot(refl_dir, L), 0.0), 180.0) * 2.5 + pow(max(dot(refl_dir, L), 0.0), 18.0) * 0.12;
		vec3 col = refr * absorb * (1.0 - fr) * (1.0 - fr * 0.6) + env * fr * reflection * 1.4 + vec3(spec) * shine * ra;
		vec4 ball = vec4(min(col, vec3(1.0)) , ra);
		ball.rgb = min(ball.rgb, vec3(ball.a));
		COLOR = mix(back, ball, inside);
	}
}
