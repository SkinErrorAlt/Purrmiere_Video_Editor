shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour_1 : source_color = vec4(1.0, 0.62, 0.74, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.72, 0.62, 1.0, 1.0);
uniform vec4 colour_3 : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 colour_4 : source_color = vec4(0.55, 0.9, 0.85, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.2;
uniform float warp : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 1.0) = 0.25;
uniform int placement : hint_range(0, 2) = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec4 place(vec4 c, vec3 g, float ga, int m) { vec4 t = vec4(clamp(g, 0.0, 1.0) * ga, ga); if (m == 0) { return over(c, t); } if (m == 1) { return over(t, c); } return t; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV;
	float t = clip_time * speed;
	p += (vec2(fbm(UV * 2.0 + t * 0.3), fbm(UV * 2.0 + 5.2 - t * 0.25)) - 0.5) * warp * 0.6;
	vec2 c1 = vec2(0.2 + 0.15 * sin(t * 0.7), 0.25 + 0.15 * cos(t * 0.5));
	vec2 c2 = vec2(0.8 + 0.12 * cos(t * 0.6), 0.2 + 0.15 * sin(t * 0.8));
	vec2 c3 = vec2(0.25 + 0.15 * cos(t * 0.9), 0.8 + 0.12 * sin(t * 0.4));
	vec2 c4 = vec2(0.78 + 0.15 * sin(t * 0.5), 0.78 + 0.12 * cos(t * 0.7));
	float w1 = 1.0 / (pow(length(p - c1), 2.2) + 0.002);
	float w2 = 1.0 / (pow(length(p - c2), 2.2) + 0.002);
	float w3 = 1.0 / (pow(length(p - c3), 2.2) + 0.002);
	float w4 = 1.0 / (pow(length(p - c4), 2.2) + 0.002);
	vec3 g = (colour_1.rgb * w1 + colour_2.rgb * w2 + colour_3.rgb * w3 + colour_4.rgb * w4) / (w1 + w2 + w3 + w4);
	g += (h12(floor(PX(UV))) - 0.5) * grain * 0.06;
	COLOR = place(c, g, 1.0, placement);
}
