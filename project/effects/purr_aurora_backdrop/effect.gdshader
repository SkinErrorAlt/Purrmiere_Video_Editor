shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour_a : source_color = vec4(0.15, 1.0, 0.6, 1.0);
uniform vec4 colour_b : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform vec4 sky : source_color = vec4(0.01, 0.02, 0.07, 1.0);
uniform float height : hint_range(0.0, 1.0) = 0.55;
uniform float intensity : hint_range(0.0, 3.0) = 1.2;
uniform float speed : hint_range(0.0, 3.0) = 0.3;
uniform float stars : hint_range(0.0, 1.0) = 0.4;
uniform int placement : hint_range(0, 2) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }
vec4 place(vec4 c, vec3 g, float ga, int m) { vec4 t = vec4(clamp(g, 0.0, 1.0) * ga, ga); if (m == 0) { return over(c, t); } if (m == 1) { return over(t, c); } return t; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 h = HN(UV);
	float t = clip_time * speed;
	vec3 g = sky.rgb * (1.0 - UV.y * 0.5) + sky.rgb * 0.5;
	vec2 sp = PX(UV) / 3.0;
	float sh = h12(floor(sp));
	g += vec3(stars * step(0.995, sh) * (0.6 + 0.4 * sin(t * 6.0 + sh * 80.0)) * smoothstep(0.5, 0.1, length(fract(sp) - 0.5)));
	vec3 au = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float x = h.x * (1.0 + fk * 0.3) + fk * 1.7;
		float cy = 1.0 - height + 0.12 * sin(x * 2.2 + t + fk) + 0.18 * (fbm(vec2(x * 0.8 + t * 0.2, fk)) - 0.5);
		float dy = UV.y - cy;
		float band = exp(-max(dy, 0.0) * 7.0) * smoothstep(-0.25 - fk * 0.05, 0.0, dy) * step(dy, 0.6);
		float rays = 0.5 + 0.5 * vn(vec2(x * 40.0, t * 0.5 + fk * 3.0));
		float up = smoothstep(0.0, -0.35, dy);
		vec3 col = mix(colour_a.rgb, colour_b.rgb, clamp(up + fk * 0.15, 0.0, 1.0));
		au += col * band * (0.4 + 0.6 * rays) * (0.6 - fk * 0.1) * smoothstep(-0.4, -0.02, dy);
	}
	g += au * intensity;
	if (placement == 1) {
		vec3 base = unp(c);
		vec3 lit = 1.0 - (1.0 - base) * (1.0 - clamp(au * intensity, 0.0, 1.0));
		COLOR = pm(lit, c.a);
	} else {
		COLOR = place(c, g, 1.0, placement);
	}
}
