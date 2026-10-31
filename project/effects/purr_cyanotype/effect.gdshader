shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 blue : source_color = vec4(0.04, 0.18, 0.42, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform float contrast : hint_range(0.2, 3.0) = 1.2;
uniform float brush : hint_range(0.0, 1.0) = 0.6;
uniform float stains : hint_range(0.0, 1.0) = 0.3;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = clamp((lum(unp(c)) - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec2 P = PX(UV);
	vec3 o = mix(blue.rgb, paper.rgb, pow(l, 1.3));
	o *= 1.0 - grain * 0.12 * (vn(P * 0.5) - 0.5) * 2.0;
	o = mix(o, o * vec3(0.92, 0.95, 1.05), stains * smoothstep(0.55, 0.8, fbm(P * 0.006)));
	vec2 e = min(UV, 1.0 - UV) * tex_size / max(px_scale, 0.0001);
	float ed = min(e.x, e.y);
	float rag = fbm(vec2(UV.x * 30.0 + UV.y * 3.0, UV.y * 30.0)) * 60.0 + fbm(P * 0.2) * 12.0;
	float coat = smoothstep(20.0, 34.0, ed - rag * brush + 30.0 * (1.0 - brush));
	o = mix(paper.rgb * (1.0 - grain * 0.05 * vn(P * 0.5)), o, coat);
	COLOR = pm(o, c.a);
}
