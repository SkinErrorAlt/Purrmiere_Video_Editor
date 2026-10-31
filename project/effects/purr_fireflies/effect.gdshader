shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.45;
uniform float size : hint_range(1.0, 20.0) = 3.0;
uniform float glow : hint_range(2.0, 80.0) = 18.0;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float speed : hint_range(0.0, 3.0) = 0.4;
uniform float blink : hint_range(0.0, 1.0) = 0.7;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float cs = glow * 5.0;
	vec2 P = PX(UV);
	float L = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		vec2 Q = P / cs + fl * vec2(0.5, 0.37) + float(seed) * 0.3;
		vec2 cl = floor(Q);
		vec2 hh = h22(cl + fl * 7.0 + float(seed));
		if (h12(cl + 2.9 + fl) > density) {
			continue;
		}
		float t = clip_time * speed;
		vec2 pos = 0.5 + 0.28 * vec2(sin(t * (0.7 + hh.x) + hh.y * 6.28), cos(t * (0.5 + hh.y) + hh.x * 6.28));
		float d = length(fract(Q) - pos) * cs;
		float bl = mix(1.0, smoothstep(0.2, 0.9, 0.5 + 0.5 * sin(clip_time * (1.0 + hh.x * 2.0) + hh.y * 30.0)), blink);
		L += (smoothstep(size, size * 0.3, d) + exp(-d * d / (glow * glow)) * 0.6) * bl * smoothstep(cs * 0.5, cs * 0.3, d);
	}
	vec3 add = colour.rgb * L * brightness;
	vec3 base = unp(c);
	vec3 o = base + add;
	float la = clamp(L * brightness, 0.0, 1.0);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
