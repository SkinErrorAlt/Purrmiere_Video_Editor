shader_type canvas_item;
render_mode blend_disabled;

uniform int placement : hint_range(0, 4) = 0;
uniform float size : hint_range(0.1, 1.0) = 0.4;
uniform float zoom : hint_range(1.0, 5.0) = 1.0;
uniform float backdrop : hint_range(0.0, 1.0) = 0.8;
uniform float gain : hint_range(0.2, 8.0) = 2.0;
uniform bool graticule = true;
uniform vec2 tex_size;

vec2 cbcr(vec3 v) {
	float y = dot(v, vec3(0.2126, 0.7152, 0.0722));
	return vec2((v.b - y) / 1.8556, (v.r - y) / 1.5748);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 bs = vec2(min(size * sz.y / sz.x, 1.0), size);
	vec2 m = vec2(0.02 * sz.y / sz.x, 0.02);
	vec2 org = (1.0 - bs) * 0.5;
	if (placement == 0) { org = 1.0 - m - bs; }
	else if (placement == 1) { org = vec2(m.x, 1.0 - m.y - bs.y); }
	else if (placement == 2) { org = vec2(1.0 - m.x - bs.x, m.y); }
	else if (placement == 3) { org = m; }
	vec2 b = (UV - org) / bs;
	vec2 q = b - 0.5;
	float bpx = bs.y * sz.y;
	if (length(q) <= 0.5) {
		vec2 pc = vec2(q.x, -q.y) / zoom;
		float w = 1.5 / (zoom * bpx);
		float acc = 0.0;
		for (int j = 0; j < 24; j++) {
			for (int i = 0; i < 24; i++) {
				vec4 s = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / 24.0);
				vec3 v = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
				vec2 d = cbcr(v) - pc;
				acc += exp(-dot(d, d) / (w * w));
			}
		}
		acc = 1.0 - exp(-acc * gain * 0.25);
		vec3 tint = clamp(vec3(0.6) + vec3(1.5748 * pc.y, -0.1873 * pc.x - 0.4681 * pc.y, 1.8556 * pc.x) * 1.6, 0.0, 1.0);
		vec3 col = mix(vec3(0.9), tint, 0.7) * acc;
		float g = 0.0;
		if (graticule) {
			float px1 = 1.0 / (zoom * bpx);
			g = max(g, (1.0 - smoothstep(0.0, px1, abs(length(pc) - 0.5 / zoom))) * 0.2);
			g = max(g, (1.0 - smoothstep(0.0, px1, min(abs(pc.x), abs(pc.y)))) * 0.12);
			vec3 tg[6] = vec3[](vec3(0.75, 0.0, 0.0), vec3(0.0, 0.75, 0.0), vec3(0.0, 0.0, 0.75), vec3(0.0, 0.75, 0.75), vec3(0.75, 0.0, 0.75), vec3(0.75, 0.75, 0.0));
			for (int k = 0; k < 6; k++) {
				vec2 t = cbcr(tg[k]);
				vec2 dd = abs(pc - t);
				float box = max(dd.x, dd.y);
				g = max(g, (1.0 - smoothstep(0.0, px1, abs(box - 0.02))) * 0.45);
			}
			vec2 sk = normalize(cbcr(vec3(0.85, 0.62, 0.5)));
			g = max(g, (1.0 - smoothstep(0.0, px1, seg(pc, vec2(0.0), sk * 0.6))) * 0.3);
		}
		vec3 bg = mix(c.rgb, vec3(0.0), backdrop);
		float edge = smoothstep(0.5, 0.5 - 1.5 / bpx, length(q));
		vec3 o = clamp(bg + col + vec3(g), 0.0, 1.0);
		COLOR = vec4(mix(c.rgb, o, edge), mix(c.a, 1.0, edge));
	} else {
		COLOR = c;
	}
}
