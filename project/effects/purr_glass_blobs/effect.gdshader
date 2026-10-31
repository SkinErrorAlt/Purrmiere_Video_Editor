shader_type canvas_item;
render_mode blend_disabled;

uniform int count : hint_range(1, 12) = 5;
uniform float size : hint_range(0.03, 0.5) = 0.16;
uniform float refraction : hint_range(0.0, 1.0) = 0.45;
uniform float chroma : hint_range(0.0, 1.0) = 0.35;
uniform float rim : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tint : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float speed : hint_range(0.0, 3.0) = 0.35;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 h = HN(UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float F = 0.0;
	vec2 gr = vec2(0.0);
	float t = clip_time * speed;
	for (int i = 0; i < 12; i++) {
		if (i >= count) {
			break;
		}
		vec2 r = h22(vec2(float(i), float(seed)) + 0.5);
		vec2 cen = vec2(0.5 * asp + 0.42 * asp * sin(t * (0.3 + r.x * 0.5) + r.y * 6.28), 0.5 + 0.38 * cos(t * (0.25 + r.y * 0.5) + r.x * 6.28));
		float rr = size * (0.7 + 0.6 * r.x);
		vec2 dv = h - cen;
		float dd = max(dot(dv, dv), 0.00001);
		F += rr * rr / dd;
		gr += -2.0 * rr * rr * dv / (dd * dd);
	}
	float inside = smoothstep(0.95, 1.05, F);
	vec2 n = gr / (length(gr) + 4.0);
	float depth = clamp((F - 1.0) * 0.5, 0.0, 1.0);
	vec2 off = -n * refraction * 0.06 * (1.0 - depth * 0.5);
	float ch = chroma * 0.012;
	vec4 sr = texture(TEXTURE, UV + off * (1.0 + ch * 20.0));
	vec4 sg = texture(TEXTURE, UV + off);
	vec4 sb = texture(TEXTURE, UV + off * (1.0 - ch * 20.0));
	vec4 g = vec4(sr.r, sg.g, sb.b, sg.a);
	g.rgb *= tint.rgb;
	float edge = smoothstep(1.0, 1.4, F) * (1.0 - smoothstep(1.4, 2.6, F));
	float hl = pow(clamp(dot(normalize(vec3(n, 0.6)), normalize(vec3(-0.5, -0.6, 0.6))), 0.0, 1.0), 12.0);
	g.rgb += vec3(edge * rim * 0.35 + hl * rim * 0.6) * max(g.a, 0.3);
	g.a = max(g.a, (edge * rim * 0.35 + hl * rim * 0.6));
	g.rgb = min(g.rgb, vec3(g.a));
	COLOR = mix(c, g, inside);
}
