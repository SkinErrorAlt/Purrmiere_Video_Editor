shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke : hint_range(2.0, 60.0) = 16.0;
uniform float width : hint_range(1.0, 20.0) = 3.5;
uniform float swirl : hint_range(0.0, 1.0) = 0.7;
uniform float flow : hint_range(20.0, 1000.0) = 220.0;
uniform float colour_boost : hint_range(0.0, 2.0) = 1.25;
uniform float texture_amount : hint_range(0.0, 1.0) = 0.6;
uniform float drift : hint_range(0.0, 2.0) = 0.0;
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
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

vec2 dir_at(sampler2D tx, vec2 uv, vec2 P) {
	float a1 = fbm(P / flow + clip_time * drift * 0.05) * 12.566;
	vec2 e = TX(2.0);
	float gx = lum(texture(tx, uv + vec2(e.x, 0.0)).rgb) - lum(texture(tx, uv - vec2(e.x, 0.0)).rgb);
	float gy = lum(texture(tx, uv + vec2(0.0, e.y)).rgb) - lum(texture(tx, uv - vec2(0.0, e.y)).rgb);
	vec2 g = vec2(-gy, gx);
	vec2 d1 = vec2(cos(a1), sin(a1));
	vec2 d2 = length(g) > 0.001 ? normalize(g) : d1;
	return normalize(mix(d2, d1, swirl) + 0.0001);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV);
	vec3 acc = vec3(0.0);
	float tex = 0.0;
	float wsum = 0.0;
	for (int side = 0; side < 2; side++) {
		vec2 p = P;
		vec2 uv = UV;
		float sg = side == 0 ? 1.0 : -1.0;
		for (int i = 0; i < 7; i++) {
			vec2 d = dir_at(TEXTURE, uv, p) * sg;
			p += d * stroke / 7.0;
			uv = p * px_scale / max(tex_size, vec2(1.0));
			float w = 1.0 - float(i) / 7.0;
			acc += unp(texture(TEXTURE, uv)) * w;
			tex += h12(floor(p / width)) * w;
			wsum += w;
		}
	}
	vec3 s = acc / wsum;
	float t = tex / wsum;
	s = mix(vec3(lum(s)), s, colour_boost);
	s *= 1.0 - texture_amount * 0.35 + texture_amount * 0.7 * t;
	COLOR = pm(s, c.a);
}
