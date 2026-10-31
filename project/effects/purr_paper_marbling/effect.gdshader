shader_type canvas_item;
render_mode blend_disabled;

uniform float swirl : hint_range(0.0, 1.0) = 0.6;
uniform float scale : hint_range(30.0, 1200.0) = 320.0;
uniform float comb : hint_range(0.0, 1.0) = 0.4;
uniform int mode : hint_range(0, 1) = 0;
uniform vec4 ink_1 : source_color = vec4(0.15, 0.25, 0.5, 1.0);
uniform vec4 ink_2 : source_color = vec4(0.75, 0.3, 0.25, 1.0);
uniform vec4 ink_3 : source_color = vec4(0.92, 0.78, 0.45, 1.0);
uniform float drift : hint_range(0.0, 2.0) = 0.1;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV) / scale;
	float t = clip_time * drift * 0.1;
	vec2 w1 = vec2(fbm(P + t), fbm(P + vec2(5.2, 1.3) - t));
	vec2 w2 = vec2(fbm(P + 4.0 * w1 * swirl + vec2(1.7, 9.2)), fbm(P + 4.0 * w1 * swirl + vec2(8.3, 2.8)));
	float cb = sin(P.x * 30.0) * comb * 0.04;
	vec2 off = (w2 - 0.5) * swirl * 0.35 + vec2(0.0, cb);
	vec3 o;
	if (mode == 0) {
		o = unp(texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0))));
	} else {
		float v = fract((P.y + off.y * 6.0 + off.x * 3.0) * 3.0);
		o = v < 0.33 ? ink_1.rgb : (v < 0.66 ? ink_2.rgb : ink_3.rgb);
		o = mix(o, vec3(0.96, 0.93, 0.85), smoothstep(0.28, 0.33, abs(fract(v * 3.0) - 0.5)) * 0.6);
	}
	COLOR = pm(o, c.a);
}
