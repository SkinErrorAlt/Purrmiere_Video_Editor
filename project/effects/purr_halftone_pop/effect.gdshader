shader_type canvas_item;
render_mode blend_disabled;

uniform float dot_size : hint_range(2.0, 60.0) = 9.0;
uniform float angle : hint_range(-90.0, 90.0) = 0.0;
uniform float pop : hint_range(0.0, 2.0) = 1.3;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 paper : source_color = vec4(0.98, 0.97, 0.93, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

float dotm(vec2 p, float cov, float ang) {
	vec2 q = rot(ang) * p / dot_size;
	float d = length(fract(q) - 0.5);
	float r = sqrt(clamp(cov, 0.0, 1.0)) * 0.71;
	float aa = (0.6 + softness * 3.0) / dot_size;
	return smoothstep(r + aa, r - aa, d);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	s = clamp(mix(vec3(lum(s)), s, pop), 0.0, 1.0);
	float k = 1.0 - max(s.r, max(s.g, s.b));
	vec3 cmy = (1.0 - s - k) / max(1.0 - k, 0.001);
	vec2 P = PX(UV);
	float a0 = radians(angle);
	vec3 o = paper.rgb;
	o *= mix(vec3(1.0), vec3(0.0, 0.68, 0.94), dotm(P, cmy.x, a0 + 0.2618));
	o *= mix(vec3(1.0), vec3(0.93, 0.0, 0.55), dotm(P, cmy.y, a0 + 1.309));
	o *= mix(vec3(1.0), vec3(1.0, 0.95, 0.0), dotm(P, cmy.z, a0));
	o *= mix(vec3(1.0), vec3(0.1, 0.1, 0.12), dotm(P, k, a0 + 0.7854));
	COLOR = pm(o, c.a);
}
