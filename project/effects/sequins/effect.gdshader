shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(5.0, 80.0) = 24.0;
uniform int finish = 0;
uniform float tilt : hint_range(0.0, 1.0) = 0.45;
uniform float sparkle : hint_range(0.0, 1.0) = 0.7;
uniform float sway : hint_range(0.0, 2.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -110.0;
uniform vec4 fabric : source_color = vec4(0.08, 0.07, 0.08, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

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

vec3 tint_of(vec3 c) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	if (finish == 1) {
		return mix(vec3(0.75, 0.55, 0.22), vec3(1.0, 0.86, 0.5), l);
	}
	if (finish == 2) {
		return mix(vec3(0.45, 0.47, 0.5), vec3(0.95, 0.96, 0.98), l);
	}
	float mx = max(c.r, max(c.g, c.b));
	vec3 hue = c / max(mx, 0.001);
	return mix(hue * max(mx, 0.08), hue, 0.35);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * tex_size / ps;
	vec2 to_uv = ps / tex_size;
	vec2 so = vec2(float(seed) * 2.37, float(seed) * 3.11);
	float D = max(size, 3.0);
	float R = D * 0.5;
	float sy = D * 0.52;
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 0.9));
	float row0 = floor(p.y / sy);
	vec3 col = fabric.rgb * (0.8 + 0.4 * vnoise(p * 0.7 + so));
	bool found = false;
	for (int dr = 1; dr >= -2; dr--) {
		if (found) {
			break;
		}
		float row = row0 + float(dr);
		float xoff = mod(row, 2.0) * 0.5 * D;
		float cx = floor((p.x - xoff) / D);
		for (int dx = -1; dx <= 1; dx++) {
			vec2 id = vec2(cx + float(dx), row);
			vec2 ctr = vec2((id.x + 0.5) * D + xoff, (row + 0.5) * sy - R * 0.25);
			ctr += (h22(id + so) - 0.5) * D * 0.06;
			vec2 q = (p - ctr) / R;
			float r = length(q);
			if (r > 1.0) {
				continue;
			}
			found = true;
			vec2 wob = (h22(id + so + 3.0) - 0.5) * 2.0 * tilt * 0.55;
			float ph = h12(id + so + 8.0) * 6.2831;
			wob += vec2(sin(time * 1.7 * sway + ph), cos(time * 1.3 * sway + ph * 1.3)) * 0.12 * sway * tilt;
			wob.y -= 0.18;
			vec3 N = normalize(vec3(wob + q * 0.06, 1.0));
			vec2 cuv = clamp(ctr * to_uv, vec2(0.0), vec2(1.0));
			vec4 sc = texture(TEXTURE, cuv);
			vec3 pc = sc.rgb / max(sc.a, 0.0001);
			vec3 tint = tint_of(pc);
			float pl = dot(pc, vec3(0.2126, 0.7152, 0.0722));
			vec3 Rv = reflect(vec3(0.0, 0.0, -1.0), N);
			vec2 env_uv = clamp(cuv + Rv.xy * 0.25, vec2(0.0), vec2(1.0));
			vec4 ec = texture(TEXTURE, env_uv);
			float env = dot(ec.rgb / max(ec.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
			float facing = clamp(dot(Rv, L), 0.0, 1.0);
			float spec = pow(facing, 90.0) * 2.2 * sparkle;
			float broad = pow(facing, 6.0);
			float bright = 0.18 + 0.6 * mix(pl, env, 0.4) + 0.4 * broad;
			vec3 s = tint * bright + mix(tint, vec3(1.0), 0.6) * spec;
			float ringv = 0.94 + 0.06 * sin(r * 18.0);
			s *= ringv;
			float rim = smoothstep(0.82, 0.97, r);
			s = mix(s, tint * 0.35 + vec3(spec * 0.5), rim * 0.6);
			s *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 0.25, 1.0 - r)) * step(0.0, -q.y);
			float hole = 1.0 - smoothstep(0.1, 0.14, r);
			float thread = (1.0 - smoothstep(0.02, 0.06, abs(q.x))) * step(q.y, 0.0) * step(-0.16, q.y);
			s = mix(s, fabric.rgb * 0.6, hole);
			s = mix(s, vec3(0.75, 0.72, 0.68) * (0.5 + 0.5 * env), thread * 0.8);
			col = s;
			break;
		}
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
