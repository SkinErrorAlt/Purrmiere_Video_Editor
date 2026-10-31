shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(3.0, 40.0) = 8.0;
uniform int levels : hint_range(2, 12) = 6;
uniform float thickness : hint_range(0.05, 0.5) = 0.34;
uniform float bare : hint_range(0.0, 1.0) = 0.92;
uniform vec4 cloth : source_color = vec4(0.95, 0.93, 0.86, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 P = PX(UV) / cell;
	vec2 cl = floor(P);
	vec2 f = fract(P);
	vec2 cuv = (cl + 0.5) * cell * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 s = unp(c);
	float lv = float(levels);
	vec3 th = floor(s * lv + 0.5) / lv;
	float d1 = abs(f.x - f.y) * 0.7071;
	float d2 = abs(f.x + f.y - 1.0) * 0.7071;
	float w = thickness * 0.5;
	float x1 = smoothstep(w, w * 0.6, d1);
	float x2 = smoothstep(w, w * 0.6, d2);
	float tw1 = 0.8 + 0.2 * sin((f.x + f.y) * 30.0);
	float tw2 = 0.8 + 0.2 * sin((f.x - f.y) * 30.0);
	vec3 wv = cloth.rgb * (0.92 + 0.08 * sin(f.x * 25.1) * sin(f.y * 25.1));
	vec2 hc = abs(f - 0.5);
	float hole = smoothstep(0.42, 0.5, max(hc.x, hc.y)) * smoothstep(0.38, 0.47, min(hc.x, hc.y));
	wv *= 1.0 - hole * 0.45;
	float on = step(lum(s), bare) * step(0.5, c.a);
	vec3 o = wv;
	o = mix(o, th * tw1 * (0.85 + 0.15 * (1.0 - d1 / w)), x1 * on);
	o = mix(o, th * tw2 * (0.9 + 0.1 * (1.0 - d2 / w)), x2 * on);
	COLOR = pm(o, c.a > 0.01 ? 1.0 : 0.0);
}
