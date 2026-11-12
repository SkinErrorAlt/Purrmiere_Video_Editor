shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float depth : hint_range(0.0, 60.0) = 20.0;
uniform float coarse : hint_range(2.0, 60.0) = 13.0;
uniform float fine : hint_range(2.0, 120.0) = 44.0;
uniform int symmetry = 7;
uniform float caustics : hint_range(0.0, 1.0) = 0.5;
uniform float shimmer : hint_range(0.0, 20.0) = 7.0;
uniform float modes : hint_range(1.0, 12.0) = 5.0;
uniform vec2 centre = vec2(0.5, 0.5);

const float HALF_TURN = 3.14159265;

void wave(vec2 p, float k, out float h, out vec2 g, out vec3 hs) {
	int n = clamp(symmetry, 2, 12);
	h = 0.0;
	g = vec2(0.0);
	hs = vec3(0.0);
	for (int j = 0; j < 12; j++) {
		if (j >= n) {
			break;
		}
		float fj = float(j);
		float ang = (fj + (snd_hash(vec2(fj, 3.7)) - 0.5) * 0.6) * HALF_TURN / float(n);
		vec2 dir = vec2(cos(ang), sin(ang));
		float kk = k * (0.85 + 0.3 * snd_hash(vec2(fj, 9.1)));
		float ph = kk * dot(p, dir) + snd_hash(vec2(fj, 1.3)) * 6.2831853;
		float c = cos(ph);
		h += c;
		g += -sin(ph) * dir / max(k, 1.0);
		hs += -c * vec3(dir.x * dir.x, dir.y * dir.y, dir.x * dir.y) * (kk * kk) / max(k * k, 1.0);
	}
	float inv = 1.0 / float(n);
	h *= inv;
	g *= inv;
	hs *= inv;
}

void fragment() {
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - centre) * asp;
	p += (vec2(snd_fbm(p * 2.5 + 3.0), snd_fbm(p * 2.5 + 11.0)) - 0.5) * 0.06;
	float drive = smoothstep(0.12, 0.85, snd_bass * 0.6 + snd_level * 0.4);
	float m = clamp(snd_bright, 0.0, 1.0) * modes;
	float m0 = floor(m);
	float t = smoothstep(0.35, 0.65, m - m0);
	float k0 = coarse * pow(fine / coarse, m0 / max(modes, 1.0));
	float k1 = coarse * pow(fine / coarse, (m0 + 1.0) / max(modes, 1.0));
	float h0;
	vec2 g0;
	vec3 s0;
	float h1;
	vec2 g1;
	vec3 s1;
	wave(p, k0, h0, g0, s0);
	wave(p, k1, h1, g1, s1);
	vec2 grad = mix(g0, g1, t);
	vec3 hs = mix(s0, s1, t);
	float osc = cos(clip_time * shimmer * 6.2831853);
	float amp = drive * osc;
	vec2 o = grad * amp * depth * px_scale / max(tex_size.y, 1.0) / asp;
	vec4 src = texture(TEXTURE, clamp(UV + o, vec2(0.0), vec2(1.0)));
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	float fd = amp * 2.6;
	float det = (1.0 + fd * hs.x) * (1.0 + fd * hs.y) - fd * fd * hs.z * hs.z;
	float g2 = clamp(1.0 / max(abs(det), 0.09) - 1.0, -0.5, 9.0);
	float c = (g2 > 0.0 ? g2 * 0.16 : g2 * 0.4) * caustics * smoothstep(0.0, 0.25, abs(amp));
	rgb = rgb * (1.0 + c) + vec3(max(c, 0.0) * 0.1);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
