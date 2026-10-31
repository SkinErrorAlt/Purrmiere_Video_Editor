shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform float cell : hint_range(20.0, 600.0) = 130.0;
uniform float rise : hint_range(0.0, 1.0) = 0.4;
uniform float rim : hint_range(0.0, 30.0) = 5.0;
uniform float film : hint_range(0.0, 1.0) = 0.8;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	vec2 P = PX(UV) / cell + float(seed) * 0.37;
	vec2 i = floor(P);
	float d = 9.0;
	float an = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = i + vec2(float(x), float(y));
			vec2 h = h22(g);
			float st = h.x * 0.45;
			float s = clamp((pg - st) / 0.55, 0.0, 1.0);
			if (s > 0.0) {
				vec2 cen = g + 0.5 + (h - 0.5) * 0.4 - vec2(0.0, s * rise);
				vec2 q = P - cen;
				float di = length(q) - s * 1.05;
				if (di < d) {
					d = di;
					an = atan(q.y, q.x);
				}
			}
		}
	}
	float px = 1.0 / cell;
	float hole = smoothstep(px, -px, d) * step(0.0001, pg);
	float rk = smoothstep(px, -px, abs(d + rim * px * 0.5) - rim * px * 0.5) * step(0.0001, pg) * step(0.01, rim) * (1.0 - smoothstep(0.9, 1.0, pg));
	vec3 rc = mix(vec3(1.0), hsv(vec3(fract(an * 0.3 + d * 3.0 + clip_time * 0.2), 0.6, 1.0)), film);
	vec4 o = c * (1.0 - hole);
	o = vec4(rc * rk, rk) + o * (1.0 - rk);
	COLOR = pg <= 0.0 ? c : o * (1.0 - smoothstep(0.96, 1.0, pg));
}
