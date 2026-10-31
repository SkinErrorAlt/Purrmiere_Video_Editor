shader_type canvas_item;
render_mode blend_disabled;

uniform float patch : hint_range(10.0, 300.0) = 56.0;
uniform float print : hint_range(0.0, 1.0) = 0.6;
uniform float puff : hint_range(0.0, 1.0) = 0.5;
uniform float stitch : hint_range(0.0, 1.0) = 0.7;
uniform vec4 thread : source_color = vec4(0.97, 0.94, 0.88, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 P = PX(UV) / patch;
	vec2 cl = floor(P);
	vec2 f = fract(P);
	vec2 cuv = (cl + 0.5) * patch * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 s = unp(c);
	vec3 lt = mix(s, vec3(1.0), 0.55);
	float typ = floor(h12(cl) * 4.0);
	float pt = 0.0;
	vec2 g = f * patch;
	if (typ < 1.0) {
		vec2 gg = step(0.5, fract(g / 10.0));
		pt = (gg.x + gg.y) * 0.5;
	} else if (typ < 2.0) {
		vec2 gv = fract(g / 11.0) - 0.5;
		pt = smoothstep(0.24, 0.18, length(gv));
	} else if (typ < 3.0) {
		pt = step(0.5, fract((g.x + g.y) / 9.0));
	}
	vec3 o = mix(s, lt, pt * print);
	vec2 e = min(f, 1.0 - f);
	float ed = min(e.x, e.y);
	o *= 1.0 - puff * 0.35 * (1.0 - smoothstep(0.0, 0.25, ed));
	o *= 1.0 + puff * 0.08 * smoothstep(0.1, 0.5, ed);
	float sl = smoothstep(0.035, 0.02, abs(ed - 0.06)) * step(0.5, fract((f.x + f.y) * patch / 8.0));
	o = mix(o, thread.rgb, sl * stitch);
	COLOR = pm(o, step(0.5, c.a));
}
