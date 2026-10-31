shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform float crinkle : hint_range(0.0, 1.0) = 0.6;
uniform float scale : hint_range(10.0, 600.0) = 120.0;
uniform float sharpness : hint_range(2.0, 80.0) = 24.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float hgt(sampler2D tx, vec2 uv, vec2 P) {
	return lum(unp(texture(tx, uv))) * 0.6 + fbm(P / scale) * crinkle;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV);
	vec2 e = TX(2.0);
	vec2 ep = vec2(2.0);
	float hx = hgt(TEXTURE, UV + vec2(e.x, 0.0), P + vec2(ep.x, 0.0)) - hgt(TEXTURE, UV - vec2(e.x, 0.0), P - vec2(ep.x, 0.0));
	float hy = hgt(TEXTURE, UV + vec2(0.0, e.y), P + vec2(0.0, ep.y)) - hgt(TEXTURE, UV - vec2(0.0, e.y), P - vec2(0.0, ep.y));
	vec3 n = normalize(vec3(-hx * 18.0, -hy * 18.0, 1.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 0.7));
	float spec = pow(clamp(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), sharpness) * strength;
	vec3 o = unp(c) * (0.9 + 0.1 * n.z) + vec3(spec);
	COLOR = pm(o, c.a);
}
