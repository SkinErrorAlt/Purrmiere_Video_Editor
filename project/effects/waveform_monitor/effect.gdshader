shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 2) = 0;
uniform int placement : hint_range(0, 4) = 0;
uniform float size : hint_range(0.1, 1.0) = 0.35;
uniform float backdrop : hint_range(0.0, 1.0) = 0.75;
uniform float gain : hint_range(0.2, 8.0) = 2.0;
uniform bool graticule = true;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 bs = placement == 4 ? vec2(1.0) : vec2(size, min(size * sz.x / sz.y * 0.5625, 1.0));
	vec2 m = vec2(0.02 * sz.y / sz.x, 0.02);
	vec2 org = vec2(0.0);
	if (placement == 0) { org = 1.0 - m - bs; }
	else if (placement == 1) { org = vec2(m.x, 1.0 - m.y - bs.y); }
	else if (placement == 2) { org = vec2(1.0 - m.x - bs.x, m.y); }
	else if (placement == 3) { org = m; }
	vec2 b = (UV - org) / bs;
	if (b.x >= 0.0 && b.y >= 0.0 && b.x <= 1.0 && b.y <= 1.0) {
		float x = b.x;
		int ch = 0;
		if (mode == 2) { ch = int(min(floor(x * 3.0), 2.0)); x = fract(x * 3.0); }
		float lvl = 1.0 - b.y;
		float bpx = bs.y * sz.y;
		float w = 1.5 / bpx;
		vec3 acc = vec3(0.0);
		for (int j = 0; j < 96; j++) {
			vec4 s = texture(TEXTURE, vec2(x, (float(j) + 0.5) / 96.0));
			vec3 v = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			if (mode == 0) {
				float l = dot(v, vec3(0.2126, 0.7152, 0.0722));
				acc += vec3(exp(-pow((l - lvl) / w, 2.0)));
			} else {
				vec3 d = (v - lvl) / w;
				acc += exp(-d * d);
			}
		}
		acc = 1.0 - exp(-acc * gain * 0.15);
		vec3 col;
		if (mode == 0) { col = vec3(0.6, 1.0, 0.65) * acc.x; }
		else if (mode == 1) { col = acc; }
		else { col = ch == 0 ? vec3(1.0, 0.3, 0.3) * acc.r : (ch == 1 ? vec3(0.3, 1.0, 0.3) * acc.g : vec3(0.35, 0.5, 1.0) * acc.b); }
		vec3 bg = mix(c.rgb, vec3(0.0), backdrop);
		float g = 0.0;
		if (graticule) {
			float dl = abs(lvl * 10.0 - round(lvl * 10.0)) / 10.0 * bpx;
			g = (1.0 - smoothstep(0.0, 1.0, dl)) * (abs(round(lvl * 10.0) - 5.0) < 0.5 ? 0.35 : 0.18);
		}
		COLOR = vec4(clamp(bg + col + vec3(g), 0.0, 1.0), 1.0);
	} else {
		COLOR = c;
	}
}
