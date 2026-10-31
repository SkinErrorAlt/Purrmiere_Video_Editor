shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform int cols : hint_range(1, 40) = 12;
uniform int rows : hint_range(1, 30) = 6;
uniform float stagger : hint_range(0.0, 1.0) = 0.6;
uniform float gap : hint_range(0.0, 6.0) = 1.5;
uniform float shade : hint_range(0.0, 1.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	vec2 n = vec2(float(cols), float(rows));
	vec2 g = UV * n;
	vec2 cl = floor(g);
	vec2 f = fract(g);
	float order = (cl.x / n.x + cl.y / n.y) * 0.5 * 0.7 + h12(cl) * 0.3;
	float s = clamp((pg - order * stagger) / max(1.0 - stagger, 0.05), 0.0, 1.0);
	vec4 o = c;
	float hole = 0.0;
	float dark = 0.0;
	if (s > 0.0) {
		if (s < 0.5) {
			float k = 1.0 - s * 2.0;
			if (f.y < 0.5) {
				float yy = 0.5 - (0.5 - f.y) / max(k, 0.0001);
				if (yy < 0.0) {
					hole = 1.0;
				} else {
					o = texture(TEXTURE, (cl + vec2(f.x, yy)) / n);
					dark = (1.0 - k) * shade;
				}
			}
		} else {
			float k = s * 2.0 - 1.0;
			if (f.y < 0.5) {
				hole = 1.0;
			} else if (f.y < 0.5 + k * 0.5) {
				hole = 1.0;
				dark = (1.0 - k) * shade;
			}
		}
	}
	vec2 e = min(f, 1.0 - f) * tex_size / n / max(px_scale, 0.0001);
	float gp = (1.0 - smoothstep(gap * 0.5, gap * 0.5 + 0.8, min(e.x, e.y))) * step(0.0001, pg) * step(0.01, gap);
	o = vec4(o.rgb * (1.0 - dark), o.a);
	o *= 1.0 - hole;
	o = mix(o, vec4(0.0, 0.0, 0.0, 1.0) * (1.0 - hole), gp * 0.8);
	COLOR = pg <= 0.0 ? c : o * (1.0 - smoothstep(0.98, 1.0, pg));
}
