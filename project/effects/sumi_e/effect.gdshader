shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_width : hint_range(1.0, 30.0) = 10.0;
uniform float stroke_pressure : hint_range(0.0, 15.0) = 2.0;
uniform float contrast : hint_range(0.0, 40.0) = 16.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
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
	float w = max(stroke_width, 0.5);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps;
	float an = radians(angle);
	vec2 dir = vec2(cos(an), -sin(an));
	vec2 nrm = vec2(-dir.y, dir.x);
	float along = dot(P, dir);
	float across = dot(P, nrm);
	vec2 wob = vec2(vn(P / (w * 1.2) + so), vn(P / (w * 1.2) + so + 23.1)) - 0.5;
	vec2 base_uv = UV + wob * w * 0.6 * ps / dims;
	vec2 step_uv = dir * w * 1.6 * ps / dims / 10.0;
	vec2 side_uv = nrm * w * ps / dims * 0.18;
	vec4 sum = vec4(0.0);
	float mn = 1.0;
	for (int i = -5; i <= 5; i++) {
		vec2 u = base_uv + step_uv * float(i);
		vec4 s = texture(TEXTURE, clamp(u, vec2(0.0), vec2(1.0)));
		sum += s;
		mn = min(mn, lum(unp(s)) + (1.0 - s.a));
		if (i % 2 == 0) {
			vec4 s1 = texture(TEXTURE, clamp(u + side_uv, vec2(0.0), vec2(1.0)));
			vec4 s2 = texture(TEXTURE, clamp(u - side_uv, vec2(0.0), vec2(1.0)));
			mn = min(mn, min(lum(unp(s1)) + (1.0 - s1.a), lum(unp(s2)) + (1.0 - s2.a)));
		}
	}
	sum /= 11.0;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 col = unp(sum);
	float bristle = vn(vec2(along / (w * 2.5), across / 1.4) + so) * 0.65 + vn(vec2(along / (w * 6.0), across / 4.0) + so + 51.0) * 0.35;
	float fuzz = vn(P / 3.0 + so + 7.7) - 0.5;
	float thr = 0.16 + stroke_pressure / 15.0 * 0.38;
	float ink = 1.0 - smoothstep(thr - 0.1, thr + 0.12, mn + fuzz * 0.12 + (bristle - 0.5) * 0.14);
	ink *= mix(0.72, 1.0, bristle);
	col = mix(col, vec3(0.03, 0.03, 0.035), clamp(ink, 0.0, 1.0) * 0.95);
	float k = contrast / 40.0;
	col = (col - 0.5) * (1.0 + k * 1.1) + 0.5 + k * 0.06;
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * a, a);
}
