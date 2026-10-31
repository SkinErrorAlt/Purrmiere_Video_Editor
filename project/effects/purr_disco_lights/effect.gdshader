shader_type canvas_item;
render_mode blend_disabled;

uniform int colour_mode : hint_range(0, 2) = 0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float size : hint_range(4.0, 200.0) = 26.0;
uniform float speed : hint_range(-3.0, 3.0) = 0.4;
uniform float dim : hint_range(0.0, 1.0) = 0.35;
uniform float strength : hint_range(0.0, 3.0) = 1.2;
uniform float glints : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float cs = size * 3.0;
	vec2 Q = PX(UV) / cs;
	Q.x += clip_time * speed * (1.0 + 0.15 * sin(Q.y * 0.5));
	Q.y += sin(Q.x * 0.3 + clip_time * 0.5) * 0.3;
	vec2 cl = floor(Q);
	vec2 hh = h22(cl);
	float on = step(h12(cl + 5.5), density);
	vec2 d = (fract(Q) - 0.5 - (hh - 0.5) * 0.3) * vec2(1.0, 1.25);
	float k = smoothstep(size / cs, size / cs * 0.5, length(d)) * on;
	vec3 col = colour.rgb;
	if (colour_mode == 0) {
		col = hsv(vec3(hh.y, 0.65, 1.0));
	} else if (colour_mode == 1) {
		col = mix(vec3(1.0, 0.45, 0.75), vec3(0.35, 0.6, 1.0), step(0.5, hh.y));
	}
	vec2 gp = PX(UV) / 7.0;
	float gh = h12(floor(gp) + floor(clip_time * 8.0) * 3.1);
	vec2 gf = fract(gp) - 0.5;
	float gl = step(0.998, gh) * (smoothstep(0.08, 0.0, abs(gf.x)) + smoothstep(0.08, 0.0, abs(gf.y))) * smoothstep(0.5, 0.0, length(gf)) * glints;
	vec3 o = s * (1.0 - dim) + s * col * k * strength + col * k * strength * 0.15 + vec3(gl);
	COLOR = pm(o, c.a);
}
