shader_type canvas_item;
render_mode blend_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.45;
uniform float size : hint_range(10.0, 400.0) = 70.0;
uniform float rise : hint_range(-2.0, 2.0) = 0.25;
uniform float film : hint_range(0.0, 1.0) = 0.8;
uniform float lens : hint_range(0.0, 1.0) = 0.4;
uniform float wobble : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float cs = size * 2.6;
	vec2 P = PX(UV) / cs;
	float t = clip_time * rise;
	vec4 o = c;
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		vec2 Q = P * (1.0 + fl * 0.6) + vec2(fl * 0.37 + float(seed) * 0.13, t * (1.0 + fl * 0.4));
		vec2 cl = floor(Q);
		vec2 hh = h22(cl + fl * 17.0 + float(seed));
		if (h12(cl + 3.3 + fl) > density) {
			continue;
		}
		float R = 0.18 + hh.x * 0.16;
		vec2 cen = 0.5 + (hh - 0.5) * (0.9 - 2.0 * R) + vec2(sin(clip_time * 1.3 + hh.y * 9.0), 0.0) * wobble * 0.08;
		vec2 d = fract(Q) - cen;
		d.x *= 1.0 + wobble * 0.04 * sin(clip_time * 4.0 + hh.x * 20.0);
		float r = length(d) / R;
		if (r < 1.0) {
			vec2 lo = d * lens * 0.25 * cs * px_scale / max(tex_size, vec2(1.0)) * (1.0 - r * r);
			vec4 bg = texture(TEXTURE, UV - lo);
			float an = atan(d.y, d.x);
			vec3 tf = hsv(vec3(fract(r * 1.3 + an * 0.08 + clip_time * 0.1 + hh.y), 0.7, 1.0));
			float rimv = pow(r, 6.0) * 0.9;
			float hl = smoothstep(0.22, 0.12, length(d / R - vec2(-0.38, -0.4)));
			vec3 add = tf * film * (rimv + 0.08) + vec3(hl * 0.85);
			float aa = clamp(rimv * 0.6 + hl * 0.85, 0.0, 1.0);
			vec4 b = bg + vec4(add, 0.0) * 0.8;
			b.a = max(b.a, aa);
			b.rgb = min(b.rgb, vec3(b.a));
			float edgeaa = smoothstep(1.0, 0.97, r);
			o = mix(o, b, edgeaa);
		}
	}
	COLOR = o;
}
