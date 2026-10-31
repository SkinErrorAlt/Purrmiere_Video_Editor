shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 blob_a : source_color = vec4(1.0, 0.35, 0.45, 1.0);
uniform vec4 blob_b : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform vec4 bg_top : source_color = vec4(0.25, 0.05, 0.35, 1.0);
uniform vec4 bg_low : source_color = vec4(0.6, 0.12, 0.35, 1.0);
uniform int blobs : hint_range(2, 12) = 7;
uniform float size : hint_range(0.03, 0.4) = 0.12;
uniform float speed : hint_range(0.0, 2.0) = 0.25;
uniform int placement : hint_range(0, 2) = 2;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }
vec4 place(vec4 c, vec3 g, float ga, int m) { vec4 t = vec4(clamp(g, 0.0, 1.0) * ga, ga); if (m == 0) { return over(c, t); } if (m == 1) { return over(t, c); } return t; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = HN(UV);
	float F = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= blobs) {
			break;
		}
		vec2 h = h22(vec2(float(i), float(seed)) + 0.3);
		float t = clip_time * speed * (0.3 + h.y * 0.4) + h.x * 10.0;
		float y = 0.5 + 0.55 * sin(t);
		float x = asp * (0.15 + 0.7 * h.x) + 0.08 * sin(t * 1.7 + h.y * 6.0);
		vec2 d = (p - vec2(x, y)) * vec2(1.0, 0.8 + 0.3 * cos(t));
		float rr = size * (0.6 + 0.8 * h.y);
		F += rr * rr / max(dot(d, d), 0.00001);
	}
	vec3 g = mix(bg_top.rgb, bg_low.rgb, UV.y);
	g += blob_a.rgb * smoothstep(0.3, 1.0, F) * 0.25;
	float k = smoothstep(0.95, 1.05, F);
	vec3 wax = mix(blob_a.rgb, blob_b.rgb, smoothstep(1.0, 3.0, F));
	g = mix(g, wax, k);
	COLOR = place(c, g, 1.0, placement);
}
