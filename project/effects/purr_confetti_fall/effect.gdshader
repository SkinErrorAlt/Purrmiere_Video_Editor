shader_type canvas_item;
render_mode blend_disabled;

uniform int palette : hint_range(0, 3) = 0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float size : hint_range(2.0, 60.0) = 12.0;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform float flutter : hint_range(0.0, 1.0) = 0.6;
uniform float shine : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

vec3 pcol(float h) {
	int i = int(h * 4.999);
	if (palette == 1) {
		vec3 p[5] = vec3[](vec3(1.0, 0.75, 0.82), vec3(0.75, 0.9, 1.0), vec3(0.8, 1.0, 0.85), vec3(1.0, 0.95, 0.7), vec3(0.85, 0.78, 1.0));
		return p[i];
	}
	if (palette == 2) {
		return i < 3 ? vec3(1.0, 0.8, 0.35) : vec3(0.85, 0.87, 0.9);
	}
	if (palette == 3) {
		vec3 p[5] = vec3[](vec3(1.0, 0.55, 0.72), vec3(0.18, 0.12, 0.35), vec3(1.0, 0.85, 0.75), vec3(0.6, 0.85, 0.9), vec3(1.0, 1.0, 1.0));
		return p[i];
	}
	vec3 p[5] = vec3[](vec3(0.95, 0.2, 0.3), vec3(1.0, 0.8, 0.1), vec3(0.15, 0.6, 1.0), vec3(0.2, 0.85, 0.4), vec3(0.85, 0.3, 0.95));
	return p[i];
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 o = c;
	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		float cs = size * (4.0 - fl * 0.8);
		vec2 Q = PX(UV) / cs;
		float colid = floor(Q.x);
		float sp = (0.6 + 0.6 * h12(vec2(colid, fl + float(seed)))) * speed;
		Q.y -= clip_time * sp * 60.0 / cs * (size / 12.0) * 2.0;
		Q.x += sin(Q.y * 0.7 + colid) * 0.25 * flutter;
		vec2 cl = floor(Q);
		vec2 hh = h22(cl + fl * 11.0 + float(seed));
		if (h12(cl + 4.1 + fl * 3.0) > density) {
			continue;
		}
		vec2 f = fract(Q) - 0.5 - (hh - 0.5) * 0.4;
		float spin = clip_time * (2.0 + hh.x * 5.0) * flutter + hh.y * 6.28;
		vec2 q = rot(hh.x * 6.28 + clip_time * flutter) * f;
		float flip = cos(spin);
		vec2 dim = vec2(0.5, 0.28) * size / cs * 1.6;
		dim.x *= max(abs(flip), 0.08);
		vec2 e = abs(q) - dim;
		float d = max(e.x, e.y) * cs;
		float k = smoothstep(0.8, -0.8, d);
		vec3 col = pcol(hh.y) * (0.65 + 0.35 * abs(flip)) + vec3(pow(abs(sin(spin * 0.5)), 12.0) * shine);
		o = mix(o, vec4(clamp(col, 0.0, 1.0), 1.0), k);
	}
	COLOR = o;
}
