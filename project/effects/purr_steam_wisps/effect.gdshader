shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 source = vec2(0.5, 0.72);
uniform float width : hint_range(0.01, 0.6) = 0.08;
uniform float height : hint_range(0.05, 1.2) = 0.5;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float curl : hint_range(0.0, 1.0) = 0.6;
uniform float speed : hint_range(0.0, 3.0) = 0.5;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float v = (source.y - UV.y) / max(height, 0.001);
	float t = clip_time * speed;
	float dx = (UV.x - source.x) * asp;
	dx -= curl * 0.06 * sin(v * 7.0 - t * 2.0) * v - curl * 0.03 * sin(v * 13.0 + t * 1.3) * v;
	float spread = width * (0.4 + v * 1.4);
	float n = fbm(vec2(dx / spread * 1.5, v * 3.5 - t * 1.2));
	float wisp = smoothstep(0.45, 0.8, n) * exp(-pow(dx / spread, 2.0));
	wisp *= smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.6, 1.0, v));
	float L = wisp * strength;
	vec3 base = unp(c);
	vec3 o = 1.0 - (1.0 - base) * (1.0 - clamp(colour.rgb * L, 0.0, 1.0));
	float la = clamp(L, 0.0, 1.0);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(o * c.a + colour.rgb * L * (1.0 - c.a), vec3(a)), a);
}
