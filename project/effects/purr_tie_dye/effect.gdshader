shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform int arms : hint_range(1, 8) = 3;
uniform float twist : hint_range(0.0, 10.0) = 3.0;
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform float bleed : hint_range(0.0, 1.0) = 0.5;
uniform float hue : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(-2.0, 2.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = max(length(q), 0.0001);
	float a = atan(q.y, q.x) / 6.28318;
	float v = a * float(arms) + log(r) * twist * 0.25 - clip_time * speed * 0.2;
	v += (fbm(PX(UV) * 0.01) - 0.5) * bleed * 0.6;
	vec3 dye = hsv(vec3(fract(v + hue), 0.85, 1.0));
	dye = mix(dye, vec3(1.0), smoothstep(0.42, 0.5, abs(fract(v * 2.0) - 0.5)) * 0.5);
	vec3 o = mix(s, dye * (0.35 + 0.85 * lum(s)), amount);
	COLOR = pm(o, c.a);
}
