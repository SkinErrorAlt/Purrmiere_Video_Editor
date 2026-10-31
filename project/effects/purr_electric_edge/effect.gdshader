shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform float inset : hint_range(0.0, 200.0) = 14.0;
uniform float jitter : hint_range(0.0, 60.0) = 14.0;
uniform float width : hint_range(0.5, 10.0) = 2.0;
uniform float rate : hint_range(1.0, 30.0) = 14.0;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P = UV * S;
	float fr = floor(clip_time * rate);
	float L = 0.0;
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float d;
		float along;
		if (mode == 0) {
			vec2 e = min(P, S - P);
			d = min(e.x, e.y) - inset;
			along = e.x < e.y ? P.y : P.x;
		} else {
			float a0 = texture(TEXTURE, UV).a;
			vec2 o = TX(inset * 0.5 + 2.0);
			float ax = texture(TEXTURE, UV + vec2(o.x, 0.0)).a - texture(TEXTURE, UV - vec2(o.x, 0.0)).a;
			float ay = texture(TEXTURE, UV + vec2(0.0, o.y)).a - texture(TEXTURE, UV - vec2(0.0, o.y)).a;
			d = (abs(a0 - 0.5) * 2.0) * (inset * 0.5 + 2.0) / max(length(vec2(ax, ay)) + 0.001, 0.5);
			along = P.x + P.y;
		}
		float off = (vn(vec2(along * 0.03, fr * 3.1 + fk * 9.0)) - 0.5) * jitter * 2.0 + (vn(vec2(along * 0.15, fr * 1.7 + fk * 4.0)) - 0.5) * jitter * 0.5;
		float dd = abs(d - off);
		L += smoothstep(width * 0.5 + 1.0, width * 0.5 - 0.3, dd) + exp(-dd / (width * 4.0)) * glow * 0.4;
	}
	vec3 add = mix(colour.rgb, vec3(1.0), clamp(L - 1.0, 0.0, 1.0) * 0.6) * L;
	vec3 base = unp(c);
	float la = clamp(L, 0.0, 1.0);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
