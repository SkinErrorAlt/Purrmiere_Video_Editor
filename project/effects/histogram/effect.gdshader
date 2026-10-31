shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 1;
uniform int placement : hint_range(0, 4) = 0;
uniform float size : hint_range(0.1, 1.0) = 0.3;
uniform float backdrop : hint_range(0.0, 1.0) = 0.75;
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
		float hgt = 1.0 - b.y;
		float bw = 1.0 / 96.0;
		vec3 acc = vec3(0.0);
		for (int j = 0; j < 24; j++) {
			for (int i = 0; i < 24; i++) {
				vec4 s = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / 24.0);
				vec3 v = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
				if (mode == 0) { v = vec3(dot(v, vec3(0.2126, 0.7152, 0.0722))); }
				vec3 d = (v - x) / bw;
				acc += exp(-d * d);
			}
		}
		vec3 dens = acc / (576.0 * bw * 1.7724539);
		vec3 bar = log(1.0 + dens) / log(9.0);
		vec3 fill = step(vec3(hgt), bar);
		vec3 col = mode == 0 ? vec3(0.85) * fill.x : vec3(1.0, 0.25, 0.25) * fill.r + vec3(0.25, 1.0, 0.25) * fill.g + vec3(0.3, 0.45, 1.0) * fill.b;
		vec3 bg = mix(c.rgb, vec3(0.0), backdrop);
		COLOR = vec4(clamp(bg + col * 0.75, 0.0, 1.0), 1.0);
	} else {
		COLOR = c;
	}
}
