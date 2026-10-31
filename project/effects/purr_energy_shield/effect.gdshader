shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float hex : hint_range(6.0, 200.0) = 40.0;
uniform float strength : hint_range(0.0, 2.0) = 0.6;
uniform float shimmer : hint_range(0.0, 3.0) = 0.8;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact_point = vec2(0.5, 0.5);
uniform float edge_only : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 P = PX(UV) / hex;
	vec2 rr = vec2(1.0, 1.7320508);
	vec2 hh = rr * 0.5;
	vec2 a = mod(P, rr) - hh;
	vec2 b = mod(P - hh, rr) - hh;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor(P - g + 0.5);
	vec2 ag = abs(g);
	float hd = 0.5 - max(dot(ag, vec2(0.5, 0.8660254)), ag.x);
	float line = smoothstep(0.06, 0.0, hd);
	float fl = 0.5 + 0.5 * sin(clip_time * shimmer * 3.0 + h12(id) * 40.0);
	float fill = pow(fl, 4.0) * 0.25;
	float rd = length((UV - impact_point) * vec2(asp, 1.0));
	float wave = impact * exp(-pow((rd - impact * 1.2) * 8.0, 2.0)) * 2.0 + impact * exp(-rd * 6.0) * (1.0 - impact);
	vec2 m = abs(UV - 0.5) * 2.0;
	float edge = mix(1.0, 0.3 + 0.7 * smoothstep(0.3, 1.0, max(m.x, m.y)), edge_only);
	float L = (line * (0.5 + 0.5 * fl) + fill + wave * (0.5 + line)) * strength * edge;
	vec4 cc = texture(TEXTURE, UV + g * wave * 0.004);
	vec3 base = unp(cc);
	vec3 add = colour.rgb * L;
	float la = clamp(L, 0.0, 1.0);
	float al = cc.a + la * (1.0 - cc.a);
	COLOR = vec4(min(base * cc.a + add, vec3(al)), al);
}
