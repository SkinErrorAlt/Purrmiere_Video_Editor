shader_type canvas_item;
render_mode blend_disabled;

uniform float level : hint_range(0.0, 1.0) = 0.6;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius : hint_range(0.02, 0.6) = 0.17;
uniform int bars : hint_range(8, 160) = 64;
uniform float reach : hint_range(0.01, 0.5) = 0.12;
uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.75, 1.0);
uniform float spin : hint_range(-2.0, 2.0) = 0.1;
uniform float glow : hint_range(0.0, 2.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = length(q);
	float a = fract(atan(q.y, q.x) / 6.28318 + clip_time * spin * 0.1);
	float n = float(bars);
	float bi = floor(a * n);
	float bf = fract(a * n);
	float fr = clip_time * 10.0;
	float hgt = level * (0.25 + 0.75 * mix(vn(vec2(bi * 0.7, floor(fr))), vn(vec2(bi * 0.7, floor(fr) + 1.0)), fract(fr)));
	hgt *= 0.8 + 0.2 * sin(bi / n * 6.28318 * 3.0 + clip_time);
	float px = px_scale / max(tex_size.y, 1.0);
	float inbar = step(radius, r) * step(r, radius + reach * hgt + px * 2.0) * smoothstep(0.15, 0.25, bf) * smoothstep(0.85, 0.75, bf);
	float ring = smoothstep(px * 2.0, 0.0, abs(r - radius + px * 3.0));
	float halo = exp(-max(r - radius, 0.0) / max(reach * 0.5, 0.001)) * glow * 0.25 * level * step(radius * 0.9, r);
	vec3 col = colour_mode == 0 ? hsv(vec3(a, 0.7, 1.0)) : colour.rgb;
	vec3 add = col * (inbar + ring * 0.8 + halo);
	float la = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	vec3 base = unp(c);
	float al = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(al)), al);
}
