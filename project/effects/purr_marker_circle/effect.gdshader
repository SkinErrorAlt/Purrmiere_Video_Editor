shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size_x : hint_range(0.02, 1.0) = 0.16;
uniform float size_y : hint_range(0.02, 1.0) = 0.12;
uniform float draw : hint_range(0.0, 1.0) = 1.0;
uniform int timing : hint_range(0, 1) = 1;
uniform float auto_len : hint_range(0.1, 5.0) = 0.6;
uniform vec4 colour : source_color = vec4(0.95, 0.15, 0.22, 1.0);
uniform float width : hint_range(1.0, 40.0) = 8.0;
uniform float overshoot : hint_range(0.0, 0.5) = 0.15;
uniform float wobble : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }

vec2 loopp(float s, float asp) {
	float w = 1.0 + (vn(vec2(s * 1.3, float(seed))) - 0.5) * wobble * 0.25 + s * 0.012;
	return vec2(cos(s - 2.2) * size_x * asp, sin(s - 2.2) * size_y) * w;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = (UV - centre) * vec2(asp, 1.0);
	float dr = timing == 1 ? clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0) : draw;
	dr = 1.0 - (1.0 - dr) * (1.0 - dr);
	float span = 6.28318 * (1.0 + overshoot) * dr;
	float best = 99.0;
	float bs = 0.0;
	vec2 prev = loopp(0.0, asp);
	for (int i = 1; i <= 64; i++) {
		float s = span * float(i) / 64.0;
		vec2 cur = loopp(s, asp);
		vec2 pa = p - prev;
		vec2 ba = cur - prev;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
		float d = length(pa - ba * h);
		if (d < best) {
			best = d;
			bs = float(i) / 64.0;
		}
		prev = cur;
	}
	float px = px_scale / max(tex_size.y, 1.0);
	float wv = width * (0.8 + 0.2 * sin(bs * 9.0)) * mix(1.0, smoothstep(0.0, 0.08, bs) * smoothstep(1.0, 0.9, bs) * 0.5 + 0.5, 0.6);
	float k = smoothstep(wv * 0.5 + 1.0, wv * 0.5 - 0.5, best / px) * step(0.0005, dr);
	k *= 0.88 + 0.12 * vn(UV * tex_size / max(px_scale, 0.0001) * 0.3);
	COLOR = mix(c, vec4(colour.rgb, 1.0), k * colour.a);
}
