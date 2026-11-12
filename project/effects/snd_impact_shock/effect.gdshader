shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float strength : hint_range(0.0, 80.0) = 34.0;
uniform float speed : hint_range(0.2, 4.0) = 1.3;
uniform float min_hit : hint_range(0.0, 1.0) = 0.3;
uniform float scatter : hint_range(0.0, 1.0) = 0.3;
uniform float fringe : hint_range(0.0, 1.0) = 0.4;
uniform float life : hint_range(0.2, 3.0) = 1.1;
uniform vec2 centre = vec2(0.5, 0.5);

void fragment() {
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = UV * asp;
	vec2 off = vec2(0.0);
	float lift = 0.0;
	int n = int(snd_hits_n);
	for (int i = 0; i < 16; i++) {
		if (i >= n) {
			break;
		}
		vec4 h = snd_hit_at(i);
		if (h.x < 0.0 || h.y < min_hit || h.x > life) {
			continue;
		}
		float low = h.w;
		float v = speed * mix(1.35, 0.6, low);
		float width = mix(0.018, 0.085, low);
		vec2 c = (centre + (snd_hash2(vec2(h.z * 71.0, h.z * 13.0 + 2.0)) - 0.5) * scatter) * asp;
		vec2 d = p - c;
		float r = length(d);
		float R = v * h.x;
		float x = (r - R) / width;
		float prof = -x * exp(-x * x);
		float fade = (1.0 - smoothstep(life * 0.35, life, h.x)) * smoothstep(0.0, 0.03, h.x);
		float amp = smoothstep(min_hit, 1.0, h.y) * 0.7 + 0.3 * h.y;
		float k = prof * amp * fade / sqrt(1.0 + R * 3.0);
		vec2 dir = r > 1e-5 ? d / r : vec2(0.0);
		off += dir * k;
		lift += exp(-x * x) * amp * fade * 0.5 / (1.0 + R * 3.0);
	}
	vec2 o = off * strength * px_scale / max(tex_size, vec2(1.0)) * 1.6;
	float fr = fringe * 0.35;
	vec4 cg = texture(TEXTURE, clamp(UV - o, vec2(0.0), vec2(1.0)));
	float rr = texture(TEXTURE, clamp(UV - o * (1.0 + fr), vec2(0.0), vec2(1.0))).r;
	float bb = texture(TEXTURE, clamp(UV - o * (1.0 - fr), vec2(0.0), vec2(1.0))).b;
	vec4 src = vec4(rr, cg.g, bb, cg.a);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	rgb *= 1.0 + lift * 0.08 * clamp(strength / 20.0, 0.0, 2.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
