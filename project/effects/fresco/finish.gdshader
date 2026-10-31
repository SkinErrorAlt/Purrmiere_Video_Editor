shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float brush_size : hint_range(1.0, 24.0) = 5.0;
uniform float detail : hint_range(0.0, 10.0) = 8.0;
uniform float texture_level : hint_range(1.0, 3.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 unp(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float bp = max(brush_size, 0.5);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 orig = unp(o);
	vec3 d = unp(texture(TEXTURE, UV));
	vec2 r = vec2(bp * 0.7 * ps) / dims;
	vec3 m = vec3(0.0);
	vec3 dark = d;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398 + 0.3;
		vec3 s = unp(texture(TEXTURE, clamp(UV + vec2(cos(an), sin(an)) * r, vec2(0.0), vec2(1.0))));
		m += s;
		dark = lum(s) < lum(dark) ? s : dark;
	}
	m /= 8.0;
	vec2 e = vec2(ps) / dims;
	vec3 ob = (unp(texture(effect_tex, UV + vec2(e.x, 0.0))) + unp(texture(effect_tex, UV - vec2(e.x, 0.0))) + unp(texture(effect_tex, UV + vec2(0.0, e.y))) + unp(texture(effect_tex, UV - vec2(0.0, e.y)))) * 0.25;
	vec3 rgb = d + (d - m) * 1.6;
	float rim = max(lum(m) - lum(d), 0.0);
	rgb *= 1.0 - clamp(rim * 2.5, 0.0, 0.7);
	rgb += (orig - ob) * detail * 0.12;
	rgb += (orig - d) * detail * 0.02;
	float tx = clamp(texture_level, 1.0, 3.0);
	float dab = vn(P / (bp * 0.8)) * 0.6 + vn(P / (bp * 0.3) + 17.3) * 0.4;
	float grain = h12(floor(P));
	float blotch = smoothstep(0.5, 0.78, dab);
	rgb = mix(rgb, dark * 0.8, blotch * (0.35 + tx * 0.15));
	rgb *= 1.0 + (dab - 0.5) * 0.2 * tx + (grain - 0.5) * 0.06 * tx;
	rgb = clamp(rgb, 0.0, 1.0);
	float l = lum(rgb);
	rgb = mix(vec3(l), rgb, 1.1);
	rgb = clamp(rgb, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	rgb = pow(rgb, vec3(1.45));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
