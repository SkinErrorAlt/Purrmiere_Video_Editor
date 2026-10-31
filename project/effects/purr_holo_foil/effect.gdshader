shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float bands : hint_range(0.5, 20.0) = 5.0;
uniform float angle : hint_range(-180.0, 180.0) = 35.0;
uniform float tilt : hint_range(-2.0, 2.0) = 0.0;
uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform float sheen : hint_range(0.0, 1.0) = 0.6;
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;
uniform float sparkle_size : hint_range(1.0, 12.0) = 3.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = unp(c);
	vec2 h = HN(UV);
	float an = radians(angle);
	float g = dot(h, vec2(cos(an), sin(an)));
	float l = lum(col);
	float ph = g * bands * 0.5 + l * 1.4 + tilt + clip_time * speed + fbm(PX(UV) * 0.004) * 0.8;
	vec3 ir = 0.5 + 0.5 * cos(6.28318 * (ph + vec3(0.0, 0.33, 0.67)));
	vec3 foil = mix(col, (col * 0.55 + 0.45) * mix(vec3(1.0), ir * 1.35, 0.9), strength);
	float sh = pow(max(0.0, sin(g * 3.0 - tilt * 3.0 - clip_time * speed * 2.0)), 24.0) * sheen;
	vec2 sp = PX(UV) / sparkle_size;
	vec2 cell = floor(sp);
	float r = length(fract(sp) - 0.5);
	float hh = h12(cell);
	float tw = step(0.93, hh) * pow(0.5 + 0.5 * sin(clip_time * 5.0 + hh * 60.0 + tilt * 9.0), 6.0);
	float glit = tw * pow(max(0.0, 1.0 - r * 2.0), 2.0) * sparkle;
	COLOR = pm(foil + vec3(sh + glit) * (0.6 + 0.4 * ir), c.a);
}
