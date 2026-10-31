shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float block : hint_range(4.0, 200.0) = 40.0;
uniform float rate : hint_range(1.0, 30.0) = 8.0;
uniform float split : hint_range(0.0, 40.0) = 6.0;
uniform float tint : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	float fr = floor(clip_time * rate) + float(seed) * 31.0;
	vec2 P = PX(UV);
	vec2 bl = floor(P / vec2(block * 3.0, block));
	float hb = h12(bl + fr * 1.7);
	float on = step(1.0 - amount * 0.35, hb);
	float shift = (h12(bl + fr * 2.3 + 5.0) - 0.5) * block * 4.0 * on;
	vec2 uv = UV + TX(1.0) * vec2(shift, 0.0);
	float sp = split * (0.4 + on * 1.2);
	vec4 cr = texture(TEXTURE, uv + TX(sp) * vec2(1.0, 0.0));
	vec4 cg = texture(TEXTURE, uv);
	vec4 cb = texture(TEXTURE, uv - TX(sp) * vec2(1.0, 0.0));
	vec3 s = vec3(unp(cr).r, unp(cg).g, unp(cb).b);
	float a = max(cg.a, max(cr.a, cb.a));
	s = mix(s, s * 0.85 + vec3(0.15), 0.4);
	float tn = step(1.0 - tint * 0.2, h12(bl + fr * 3.1 + 9.0));
	vec3 pc = h12(bl + 4.4) < 0.33 ? vec3(1.0, 0.7, 0.85) : (h12(bl + 4.4) < 0.66 ? vec3(0.7, 1.0, 0.88) : vec3(0.82, 0.75, 1.0));
	s = mix(s, pc * (0.6 + 0.4 * lum(s)) * (0.85 + 0.15 * sin(P.y * 2.0)), tn * 0.8);
	COLOR = pm(s, a);
}
