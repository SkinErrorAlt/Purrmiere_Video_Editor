shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(8.0, 200.0) = 38.0;
uniform float lead : hint_range(0.0, 12.0) = 3.0;
uniform vec4 lead_colour : source_color = vec4(0.07, 0.06, 0.06, 1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.4;
uniform float glow : hint_range(0.0, 1.0) = 0.5;
uniform float ripple : hint_range(0.0, 1.0) = 0.4;
uniform float sweep : hint_range(0.0, 1.0) = 0.4;
uniform float speed : hint_range(0.0, 2.0) = 0.25;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec4 vor(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); float d1 = 8.0; float d2 = 8.0; vec2 c = vec2(0.0); for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) { vec2 g = vec2(float(x), float(y)); vec2 o = g + h22(i + g); float d = length(o - f); if (d < d1) { d2 = d1; d1 = d; c = i + o; } else if (d < d2) { d2 = d; } } } return vec4(c, d1, d2 - d1); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 so = vec2(float(seed) * 7.31, float(seed) * 3.17);
	vec2 P = PX(UV) / cell + so;
	vec4 v = vor(P);
	vec2 cuv = (v.xy - so) * cell * px_scale / max(tex_size, vec2(1.0));
	vec4 g4 = texture(TEXTURE, clamp(cuv, vec2(0.0), vec2(1.0)));
	vec3 g = unp(g4);
	g = mix(vec3(lum(g)), g, saturation);
	g *= 1.0 - ripple * 0.3 + ripple * 0.6 * vn(PX(UV) * 0.07 + so);
	g *= 1.0 + glow * (0.6 - v.z);
	float sw = fract(UV.x * 0.6 + UV.y * 0.4 - clip_time * speed * 0.3);
	g += sweep * vec3(1.0, 0.95, 0.8) * pow(max(0.0, 1.0 - abs(sw - 0.5) * 5.0), 3.0) * 0.6;
	float lw = lead * 0.5 / cell;
	float aa = 1.0 / cell;
	float k = (1.0 - smoothstep(lw, lw + aa, v.w)) * step(0.01, lead);
	float a = max(g4.a, c.a * k);
	COLOR = pm(mix(g, lead_colour.rgb, k), a);
}
