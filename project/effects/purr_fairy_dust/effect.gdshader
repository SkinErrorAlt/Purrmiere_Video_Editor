shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 head_colour : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.05, 1.0) = 0.38;
uniform float speed : hint_range(-3.0, 3.0) = 0.5;
uniform float trail : hint_range(0.05, 1.0) = 0.45;
uniform float sparkle : hint_range(1.0, 30.0) = 8.0;
uniform float fall : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }

vec2 path(float s) {
	return vec2(sin(s * 1.0) * size * 1.5, sin(s * 2.0 + 0.6) * size * 0.6);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = (UV - centre) * vec2(asp, 1.0);
	float head = clip_time * speed * 2.0;
	float px = px_scale / max(tex_size.y, 1.0);
	float L = 0.0;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 48; i++) {
		vec2 hh = h22(vec2(float(i), float(seed)));
		float u = fract(hh.x + clip_time * 0.7 * abs(speed) + float(i) * 0.013);
		float s = head - u * trail * 6.28318;
		vec2 sp = path(s) + (h22(vec2(float(i), floor(hh.x + clip_time * 0.7 * abs(speed) + float(i) * 0.013))) - 0.5) * 0.08 * u + vec2(0.0, u * u * fall * 0.25);
		float d = length(p - sp) / px;
		float tw = 0.5 + 0.5 * sin(clip_time * 12.0 + hh.y * 50.0);
		float sz = sparkle * (1.0 - u * 0.7);
		vec2 dv = abs(p - sp) / px;
		float star = smoothstep(sz, 0.0, d) + smoothstep(sz * 0.18, 0.0, min(dv.x, dv.y)) * smoothstep(sz * 2.5, 0.0, d) * 0.7;
		add += colour.rgb * star * tw * (1.0 - u);
	}
	float dh = length(p - path(head)) / px;
	add += head_colour.rgb * (smoothstep(sparkle * 2.0, 0.0, dh) + exp(-dh / (sparkle * 4.0)) * 0.6);
	float la = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	vec3 base = unp(c);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
