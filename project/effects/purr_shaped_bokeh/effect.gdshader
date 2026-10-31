shader_type canvas_item;
render_mode blend_disabled;

uniform int shape : hint_range(0, 4) = 0;
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float size : hint_range(6.0, 300.0) = 50.0;
uniform float softness : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.0, 2.0) = 0.8;
uniform int colour_mode : hint_range(0, 2) = 0;
uniform float speed : hint_range(0.0, 3.0) = 0.25;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

float sde(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float sdshape(vec2 p) {
	if (shape == 0) {
		vec2 q = vec2(abs(p.x), -p.y) * 1.3 + vec2(0.0, 0.62);
		if (q.y + q.x > 1.0) {
			return (length(q - vec2(0.25, 0.75)) - 0.353553) / 1.3;
		}
		vec2 a = q - vec2(0.0, 1.0);
		vec2 b = q - 0.5 * max(q.x + q.y, 0.0);
		return sqrt(min(dot(a, a), dot(b, b))) * sign(q.x - q.y) / 1.3;
	}
	if (shape == 1) {
		float an = atan(p.y, p.x) + 1.5708;
		float k = abs(fract(an / 1.256637) - 0.5) * 2.0;
		return length(p) - mix(0.24, 0.5, pow(k, 1.6));
	}
	if (shape == 2) {
		vec2 q = p * 1.2;
		float d = sde(q - vec2(0.0, 0.12), vec2(0.3, 0.24));
		d = min(d, sde(q - vec2(-0.35, -0.19), vec2(0.11, 0.13)));
		d = min(d, sde(q - vec2(-0.125, -0.37), vec2(0.115, 0.14)));
		d = min(d, sde(q - vec2(0.125, -0.37), vec2(0.115, 0.14)));
		d = min(d, sde(q - vec2(0.35, -0.19), vec2(0.11, 0.13)));
		return d / 1.2;
	}
	if (shape == 3) {
		vec2 q = abs(p);
		return max(q.x * 0.866025 + q.y * 0.5, q.y) - 0.42;
	}
	return length(p) - 0.45;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 add = vec3(0.0);
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		float cs = size * (2.2 - fl * 0.8);
		vec2 Q = PX(UV) / cs + vec2(clip_time * speed * (0.3 + fl * 0.2), -clip_time * speed * 0.15) + fl * 5.3 + float(seed) * 0.71;
		vec2 cl = floor(Q);
		vec2 hh = h22(cl + float(seed));
		if (h12(cl + 1.7 + fl) > density) {
			continue;
		}
		vec2 cen = 0.5 + (hh - 0.5) * 0.4;
		float rs = 0.7 + 0.5 * hh.x;
		vec2 p = (fract(Q) - cen) / (size / cs * rs);
		float d = sdshape(p);
		float soft = 0.02 + softness * 0.25;
		float k = smoothstep(soft, -soft, d) * (0.75 + 0.25 * smoothstep(-0.3, 0.0, d));
		vec3 col;
		if (colour_mode == 0) {
			vec2 cuv = (cl + cen - vec2(clip_time * speed * (0.3 + fl * 0.2), -clip_time * speed * 0.15) - fl * 5.3 - float(seed) * 0.71) * cs * px_scale / max(tex_size, vec2(1.0));
			col = unp(texture(TEXTURE, clamp(cuv, vec2(0.0), vec2(1.0)))) * 1.2 + 0.1;
		} else if (colour_mode == 1) {
			col = mix(vec3(1.0, 0.55, 0.75), vec3(1.0, 0.82, 0.4), step(0.5, hh.y));
		} else {
			col = hsv(vec3(hh.y, 0.6, 1.0));
		}
		add += col * k * brightness * (0.5 + 0.5 * hh.y) * (1.0 - fl * 0.3);
	}
	vec3 base = unp(c);
	vec3 o = 1.0 - (1.0 - base) * (1.0 - clamp(add, 0.0, 1.0));
	float la = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(o * c.a + add * (1.0 - c.a), vec3(a)), a);
}
