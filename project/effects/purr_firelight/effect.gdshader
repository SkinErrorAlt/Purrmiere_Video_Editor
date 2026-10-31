shader_type canvas_item;
render_mode blend_disabled;

uniform int preset : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform vec2 source = vec2(0.5, 1.1);
uniform float reach : hint_range(0.1, 3.0) = 1.1;
uniform float strength : hint_range(0.0, 3.0) = 1.2;
uniform float ambient : hint_range(0.0, 1.0) = 0.35;
uniform float flicker : hint_range(0.0, 1.0) = 0.6;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float t = clip_time * speed;
	float n = 0.55 * sin(t * 7.3) + 0.3 * sin(t * 13.1 + 1.3) + 0.25 * sin(t * 23.7 + 0.4) + 0.4 * (vn(vec2(t * 9.0, 2.0)) - 0.5) * 2.0;
	vec3 col = colour.rgb;
	if (preset == 0) {
		col = mix(vec3(1.0, 0.42, 0.12), vec3(1.0, 0.7, 0.3), 0.5 + 0.5 * sin(t * 5.0));
	} else if (preset == 1) {
		col = vec3(1.0, 0.68, 0.35);
		n *= 0.5;
	} else if (preset == 2) {
		float fr = floor(t * 6.0);
		col = mix(vec3(0.45, 0.6, 1.0), vec3(0.8, 0.85, 1.0), h12(vec2(fr, 1.0)));
		n = (h12(vec2(fr, 3.0)) - 0.5) * 1.6;
	}
	float I = 1.0 + n * flicker * 0.35;
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float d = length((UV - source) * vec2(asp, 1.0));
	float fall = exp(-d * d / max(reach * reach, 0.0001) * 1.5);
	vec3 o = s * (ambient + col * fall * I * strength);
	COLOR = pm(o, c.a);
}
