shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.84, 0.6, 1.0);
uniform int panes : hint_range(1, 8) = 2;
uniform int rows : hint_range(1, 8) = 2;
uniform float angle : hint_range(-80.0, 80.0) = 22.0;
uniform float skew : hint_range(-1.0, 1.0) = 0.35;
uniform float size : hint_range(0.2, 3.0) = 1.0;
uniform float bars : hint_range(0.0, 0.4) = 0.08;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform float motes : hint_range(0.0, 1.0) = 0.4;
uniform float drift : hint_range(-1.0, 1.0) = 0.05;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 h = HN(UV) - vec2(0.5 * tex_size.x / max(tex_size.y, 1.0), 0.5);
	h.x -= clip_time * drift * 0.1;
	vec2 q = rot(radians(angle)) * h;
	q.x += q.y * skew;
	q /= size;
	vec2 g = q * vec2(float(panes), float(rows)) * 0.9 + vec2(float(panes), float(rows)) * 0.5;
	vec2 f = fract(g);
	float soft = 0.01 + softness * 0.2;
	float inwin = smoothstep(-soft, soft, min(g.x, g.y)) * smoothstep(-soft, soft, min(float(panes) - g.x, float(rows) - g.y));
	vec2 e = min(f, 1.0 - f);
	float pane = smoothstep(bars * 0.5, bars * 0.5 + soft, min(e.x, e.y));
	float L = inwin * pane;
	vec2 P = PX(UV);
	vec2 mp = P / 5.0 + vec2(sin(clip_time * 0.3 + floor(P.y / 80.0)) * 0.4, clip_time * 0.6);
	float mh = h12(floor(mp));
	float mote = step(0.993, mh) * smoothstep(0.5, 0.0, length(fract(mp) - 0.5)) * (0.5 + 0.5 * sin(clip_time * 2.0 + mh * 50.0));
	vec3 o = s * (1.0 - shadow * (1.0 - L)) + s * colour.rgb * L * strength + colour.rgb * L * strength * 0.12;
	o += colour.rgb * mote * motes * L * 1.5;
	COLOR = pm(o, c.a);
}
