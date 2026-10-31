shader_type canvas_item;
render_mode blend_disabled;

uniform int preset : hint_range(0, 3) = 0;
uniform float contrast : hint_range(0.2, 3.0) = 1.15;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform float border : hint_range(0.0, 120.0) = 24.0;
uniform vec4 border_colour : source_color = vec4(0.95, 0.91, 0.8, 1.0);
uniform float hue_keep : hint_range(0.0, 1.0) = 0.3;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

vec3 ramp(int p, int i) {
	if (p == 1) {
		vec3 a[6] = vec3[](vec3(0.25, 0.12, 0.12), vec3(0.6, 0.22, 0.15), vec3(0.85, 0.42, 0.2), vec3(0.93, 0.66, 0.35), vec3(0.97, 0.84, 0.6), vec3(0.98, 0.95, 0.85));
		return a[i];
	}
	if (p == 2) {
		vec3 a[6] = vec3[](vec3(0.1, 0.16, 0.25), vec3(0.18, 0.35, 0.45), vec3(0.3, 0.55, 0.5), vec3(0.6, 0.75, 0.7), vec3(0.85, 0.9, 0.88), vec3(0.98, 0.98, 0.96));
		return a[i];
	}
	if (p == 3) {
		vec3 a[6] = vec3[](vec3(0.06, 0.05, 0.15), vec3(0.2, 0.1, 0.35), vec3(0.55, 0.15, 0.45), vec3(0.95, 0.35, 0.45), vec3(1.0, 0.7, 0.4), vec3(1.0, 0.93, 0.7));
		return a[i];
	}
	vec3 a[6] = vec3[](vec3(0.06, 0.18, 0.3), vec3(0.08, 0.38, 0.55), vec3(0.2, 0.62, 0.72), vec3(0.95, 0.55, 0.35), vec3(0.98, 0.8, 0.55), vec3(0.98, 0.95, 0.86));
	return a[i];
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 P = PX(UV);
	float l = clamp((lum(s) - 0.5) * contrast + 0.5 + (vn(P * 0.8) - 0.5) * grain * 0.08, 0.0, 0.999);
	int i = int(l * 6.0);
	vec3 o = ramp(preset, i);
	o = mix(o, o * (s / max(lum(s), 0.05)), hue_keep * 0.5);
	o *= 1.0 - grain * 0.08 * vn(P * 1.7);
	vec2 e = min(UV, 1.0 - UV) * tex_size / max(px_scale, 0.0001);
	float bd = 1.0 - smoothstep(border - 0.5, border + 0.5, min(e.x, e.y));
	bd *= step(0.01, border);
	o = mix(o, border_colour.rgb, bd);
	COLOR = pm(o, max(c.a, bd));
}
