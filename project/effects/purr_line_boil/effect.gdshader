shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 12.0) = 2.5;
uniform float rate : hint_range(1.0, 30.0) = 10.0;
uniform float scale : hint_range(4.0, 300.0) = 40.0;
uniform float shake : hint_range(0.0, 10.0) = 1.0;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	float fr = floor(clip_time * rate) + float(seed) * 17.0;
	vec2 P = PX(UV) / scale;
	vec2 o = vec2(vn(P + fr * 3.17), vn(P + vec2(5.2, 1.3) + fr * 2.71)) - 0.5;
	vec2 sh = (h22(vec2(fr, 1.0)) - 0.5) * shake;
	vec4 c = texture(TEXTURE, UV + TX(1.0) * (o * amount * 2.0 + sh));
	COLOR = c;
}
