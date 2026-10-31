shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tail = vec2(0.25, 0.75);
uniform vec2 tip = vec2(0.55, 0.45);
uniform float bend : hint_range(-1.0, 1.0) = 0.3;
uniform float draw : hint_range(0.0, 1.0) = 1.0;
uniform int timing : hint_range(0, 1) = 1;
uniform float auto_len : hint_range(0.1, 5.0) = 0.5;
uniform vec4 colour : source_color = vec4(0.95, 0.15, 0.22, 1.0);
uniform float width : hint_range(1.0, 40.0) = 8.0;
uniform float head : hint_range(0.01, 0.3) = 0.06;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

vec2 bez(vec2 a, vec2 b, vec2 c, float t) {
	return mix(mix(a, c, t), mix(c, b, t), t);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 A = tail * vec2(asp, 1.0);
	vec2 B = tip * vec2(asp, 1.0);
	vec2 dv = B - A;
	vec2 C = (A + B) * 0.5 + vec2(-dv.y, dv.x) * bend * 0.6;
	vec2 p = UV * vec2(asp, 1.0);
	float dr = timing == 1 ? clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0) : draw;
	float sh = clamp(dr / 0.8, 0.0, 1.0);
	float best = 99.0;
	vec2 prev = A;
	for (int i = 1; i <= 40; i++) {
		vec2 cur = bez(A, B, C, sh * float(i) / 40.0);
		best = min(best, seg(p, prev, cur));
		prev = cur;
	}
	vec2 tdir = normalize(B - bez(A, B, C, 0.95) + 0.000001);
	float hv = clamp((dr - 0.8) / 0.2, 0.0, 1.0);
	vec2 h1 = B - rot(0.5) * tdir * head * hv;
	vec2 h2 = B - rot(-0.5) * tdir * head * hv;
	if (hv > 0.0) {
		best = min(best, min(seg(p, B, h1), seg(p, B, h2)));
	}
	float px = px_scale / max(tex_size.y, 1.0);
	float k = smoothstep(width * 0.5 + 1.0, width * 0.5 - 0.5, best / px) * step(0.0005, dr);
	k *= 0.88 + 0.12 * vn(UV * tex_size / max(px_scale, 0.0001) * 0.3);
	COLOR = mix(c, vec4(colour.rgb, 1.0), k * colour.a);
}
