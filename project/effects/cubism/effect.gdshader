shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(4.0, 300.0) = 24.0;
uniform float saturation : hint_range(0.0, 10.0) = 2.5;
uniform int background = 0;
uniform vec4 bg_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float cell = max(size * max(px_scale, 0.0001), 2.0);
	float sf = float(seed);
	vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
	vec2 p = UV * dims;
	vec2 base = floor(p / cell);
	float pri[27];
	vec4 col[27];
	float alpha[27];
	int n = 0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = base + vec2(float(x), float(y));
			for (int k = 0; k < 3; k++) {
				vec4 h = hash42(id * 1.37 + so + vec2(float(k) * 17.17, float(k) * 5.31));
				vec4 h2 = hash42(id * 2.11 + so + vec2(float(k) * 9.73 + 3.1, 41.7));
				vec2 ctr = (id + h.xy) * cell;
				float half_size = cell * (0.36 + 0.26 * h.z);
				float a = h.w * 1.57079632679;
				vec2 d = p - ctr;
				float cs = cos(a);
				float sn = sin(a);
				vec2 l = vec2(d.x * cs + d.y * sn, -d.x * sn + d.y * cs);
				float inside = half_size - max(abs(l.x), abs(l.y));
				float al = clamp(max(saturation, 0.0) * inside / half_size, 0.0, 1.0);
				if (inside > 0.0 && al > 0.0) {
					alpha[n] = al;
					col[n] = texture(TEXTURE, clamp(ctr / dims, vec2(0.0), vec2(1.0)));
					pri[n] = h2.x;
					n++;
				}
			}
		}
	}
	vec4 src = texture(TEXTURE, UV);
	vec4 outc = vec4(0.0);
	if (background == 0) {
		outc = vec4(bg_colour.rgb * bg_colour.a, bg_colour.a);
	} else if (background == 1) {
		outc = src;
	}
	float last = -1.0;
	for (int s = 0; s < n; s++) {
		float next = 2.0;
		int pick = -1;
		for (int i = 0; i < n; i++) {
			if (pri[i] > last && pri[i] < next) {
				next = pri[i];
				pick = i;
			}
		}
		if (pick < 0) {
			break;
		}
		last = next;
		if (alpha[pick] > 0.0) {
			outc = mix(outc, col[pick], alpha[pick]);
		}
	}
	COLOR = outc;
}
