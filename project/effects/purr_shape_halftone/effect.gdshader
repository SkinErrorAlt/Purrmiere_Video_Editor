shader_type canvas_item;
render_mode blend_disabled;

uniform int shape : hint_range(0, 3) = 0;
uniform float cell : hint_range(4.0, 80.0) = 16.0;
uniform float angle : hint_range(-90.0, 90.0) = 15.0;
uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 ink : source_color = vec4(0.15, 0.08, 0.2, 1.0);
uniform vec4 paper : source_color = vec4(0.98, 0.95, 0.92, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

float sde(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float sdshape(vec2 p) {
	if (shape == 0) {
		float d = sde(p - vec2(0.0, 0.12), vec2(0.3, 0.24));
		d = min(d, sde(p - vec2(-0.35, -0.19), vec2(0.11, 0.13)));
		d = min(d, sde(p - vec2(-0.125, -0.37), vec2(0.115, 0.14)));
		d = min(d, sde(p - vec2(0.125, -0.37), vec2(0.115, 0.14)));
		d = min(d, sde(p - vec2(0.35, -0.19), vec2(0.11, 0.13)));
		return d;
	}
	if (shape == 1) {
		vec2 q = vec2(abs(p.x), -p.y) * 1.3 + vec2(0.0, 0.62);
		if (q.y + q.x > 1.0) {
			return (length(q - vec2(0.25, 0.75)) - 0.353553) / 1.3;
		}
		vec2 a = q - vec2(0.0, 1.0);
		vec2 b = q - 0.5 * max(q.x + q.y, 0.0);
		return sqrt(min(dot(a, a), dot(b, b))) * sign(q.x - q.y) / 1.3;
	}
	if (shape == 2) {
		float an = atan(p.y, p.x) + 1.5708;
		float k = abs(fract(an / 1.256637) - 0.5) * 2.0;
		return (length(p) - mix(0.22, 0.5, pow(k, 1.6))) * 0.8;
	}
	return length(p) - 0.45;
}

void fragment() {
	vec2 P = rot(radians(angle)) * PX(UV) / cell;
	vec2 cl = floor(P);
	vec2 f = fract(P) - 0.5;
	vec2 cen = rot(-radians(angle)) * ((cl + 0.5) * cell);
	vec4 sc = texture(TEXTURE, clamp(cen * px_scale / max(tex_size, vec2(1.0)), vec2(0.0), vec2(1.0)));
	vec3 s = unp(sc);
	float l = lum(s);
	float sz = colour_mode == 0 ? sqrt(1.0 - l) : sqrt(l);
	sz *= 1.25;
	float d = sz > 0.01 ? sdshape(f / sz) * sz * cell : 99.0;
	float k = smoothstep(0.7, -0.7, d);
	vec3 o = colour_mode == 0 ? mix(paper.rgb, ink.rgb, k) : mix(ink.rgb * 0.3, s, k);
	COLOR = pm(o, texture(TEXTURE, UV).a);
}
