shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.9, 0.68, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform float shadow : hint_range(0.0, 1.0) = 0.45;
uniform float size : hint_range(20.0, 1000.0) = 180.0;
uniform float spots : hint_range(0.0, 1.0) = 0.6;
uniform float sway : hint_range(0.0, 2.0) = 0.4;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec4 vor(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); float d1 = 8.0; float d2 = 8.0; vec2 c = vec2(0.0); for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) { vec2 g = vec2(float(x), float(y)); vec2 o = g + h22(i + g); float d = length(o - f); if (d < d1) { d2 = d1; d1 = d; c = i + o; } else if (d < d2) { d2 = d; } } } return vec4(c, d1, d2 - d1); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 P = PX(UV) / size;
	vec2 sw = vec2(sin(clip_time * 0.7), cos(clip_time * 0.53)) * 0.08 * sway;
	float n = fbm(P + sw + vec2(sin(clip_time * 0.3) * 0.05 * sway, 0.0));
	float soft = 0.03 + softness * 0.15;
	float L = smoothstep(0.52 - soft, 0.52 + soft, n);
	vec4 v = vor(P * 2.5 + sw * 3.0);
	float sp = smoothstep(0.3 + softness * 0.15, 0.12, v.z) * step(0.45, n) * spots;
	L = clamp(max(L * 0.8, sp), 0.0, 1.0);
	vec3 o = s * (1.0 - shadow * (1.0 - L)) + s * colour.rgb * L * strength * 0.8 + colour.rgb * L * strength * 0.06;
	COLOR = pm(o, c.a);
}
