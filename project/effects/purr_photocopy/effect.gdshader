shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform int generations : hint_range(1, 6) = 2;
uniform float toner : hint_range(0.0, 1.0) = 0.45;
uniform float streaks : hint_range(0.0, 1.0) = 0.35;
uniform float skew : hint_range(-5.0, 5.0) = 0.6;
uniform float lid : hint_range(0.0, 1.0) = 0.4;
uniform vec4 paper : source_color = vec4(0.97, 0.97, 0.95, 1.0);
uniform vec4 toner_colour : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 q = rot(radians(skew)) * (UV - 0.5) + 0.5;
	vec4 c = texture(TEXTURE, q);
	float inside = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
	float l = lum(unp(c));
	float g = float(generations);
	float w = 0.35 / g;
	float k = 1.0 - smoothstep(threshold - w, threshold + w, l);
	vec2 P = PX(UV);
	float sp = h12(floor(P * 0.8));
	float sp2 = h12(floor(P * 0.35) + 3.0);
	k = max(k, step(1.0 - toner * 0.012 * g, sp));
	k *= 1.0 - step(1.0 - toner * 0.02 * g, sp2) * 0.8;
	float st = smoothstep(0.7, 0.95, vn(vec2(P.x * 0.05, P.y * 0.002))) * streaks;
	k = max(k, st * 0.6 * (0.5 + 0.5 * vn(P * 0.1)));
	vec2 e = min(UV, 1.0 - UV);
	float lidv = (1.0 - smoothstep(0.0, 0.06, min(e.x, e.y))) * lid;
	k = max(k, lidv * (0.6 + 0.4 * vn(P * 0.05)));
	k = max(k * inside, (1.0 - inside) * lid * 0.8);
	COLOR = pm(mix(paper.rgb, toner_colour.rgb, clamp(k, 0.0, 1.0)), max(c.a, 1.0 - inside));
}
