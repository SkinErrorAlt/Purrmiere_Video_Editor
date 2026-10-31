shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 ring_colour : source_color = vec4(0.65, 0.35, 1.0, 1.0);
uniform float ring : hint_range(0.0, 0.3) = 0.06;
uniform float twist : hint_range(0.0, 20.0) = 6.0;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	float pg = PG();
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = length(q);
	float R = pow(pg, 1.5) * 1.2 * length(vec2(asp, 1.0) * 0.5 + abs(centre - 0.5) * vec2(asp, 1.0));
	float an = twist * pg * exp(-max(r - R, 0.0) * 3.0);
	vec2 sq = rot(an) * q * (1.0 - pg * 0.3 * exp(-max(r - R, 0.0) * 4.0));
	vec4 c = texture(TEXTURE, centre + sq / vec2(asp, 1.0));
	float a = atan(q.y, q.x);
	float sw = fbm(vec2(a * 2.0 + r * 8.0 - clip_time * 3.0, r * 6.0 - clip_time));
	float band = ring * (0.6 + 0.8 * sw);
	float px = px_scale / max(tex_size.y, 1.0);
	float hole = smoothstep(px, -px, r - R);
	float rg = smoothstep(band, 0.0, abs(r - R)) * step(0.0001, pg);
	float gl = exp(-abs(r - R) * 12.0) * glow * step(0.0001, pg);
	vec4 o = c * (1.0 - hole);
	vec3 light = ring_colour.rgb * (rg * 1.2 + gl * 0.5) + vec3(rg * rg * 0.6);
	float la = clamp(rg + gl * 0.5, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, pg));
	o = vec4(light * la, la) + o * (1.0 - la);
	COLOR = pg <= 0.0 ? texture(TEXTURE, UV) : o * (1.0 - smoothstep(0.97, 1.0, pg));
}
