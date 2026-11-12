shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float wear_time : hint_range(0.5, 120.0) = 8.0;
uniform float fade : hint_range(0.0, 1.0) = 0.6;
uniform float abrasion : hint_range(0.0, 1.0) = 0.7;
uniform float scuffs : hint_range(0.0, 1.0) = 0.6;
uniform float size : hint_range(0.2, 4.0) = 1.0;
uniform vec4 base_colour : source_color = vec4(0.86, 0.82, 0.72, 1.0);
uniform int seed = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float scratch_field(vec2 p, float w, float px) {
	float best = 0.0;
	vec2 cell = floor(p * 14.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float born = snd_hash(c * 1.7 + float(seed));
			if (born > w) {
				continue;
			}
			vec2 h = snd_hash2(c * 3.1 + float(seed) * 0.37);
			vec2 o = (c + h) / 14.0;
			float ang = snd_hash(c + 5.0) * 3.14159;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 q = p - o;
			float along = dot(q, dir);
			float len = 0.012 + 0.05 * snd_hash(c + 9.0);
			float across = abs(dot(q, vec2(-dir.y, dir.x)));
			float fadein = smoothstep(born, born + 0.15, w);
			float l = (1.0 - smoothstep(px * 0.3, px * 1.1, across)) * (1.0 - smoothstep(len * 0.6, len, abs(along)));
			best = max(best, l * fadein * (0.25 + 0.4 * snd_hash(c + 2.0)));
		}
	}
	return best;
}

void fragment() {
	float w = 1.0 - exp(-snd_dose / max(wear_time, 0.01));
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec2 asp = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = UV * asp / max(size, 0.05);
	float px = px_scale / max(tex_size.y, 1.0) / max(size, 0.05);
	float y = dot(rgb, LUMA);
	vec3 faded = mix(vec3(y), rgb, 0.45) * 0.82 + base_colour.rgb * 0.2;
	faded = mix(faded, faded * vec3(1.04, 1.0, 0.86), 0.5);
	rgb = mix(rgb, faded, w * fade);
	float n = snd_fbm(p * 1.7 + float(seed) * 1.7);
	float fine = snd_vnoise(p * 140.0);
	vec2 e2 = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.22, min(e2.x * asp.x / asp.y, e2.y));
	float edge_n = n + (fine - 0.5) * 0.08 - edge * 0.28;
	float reach = w * abrasion * 1.05;
	float worn = 1.0 - smoothstep(reach - 0.03, reach + 0.01, edge_n + 0.4);
	float rim = (1.0 - smoothstep(reach - 0.01, reach + 0.05, edge_n + 0.4)) - worn;
	vec3 paper = base_colour.rgb * (0.88 + 0.12 * fine) * (0.8 + 0.2 * snd_vnoise(p * 30.0));
	vec3 thin = mix(rgb, paper, 0.45 + 0.3 * fine);
	rgb = mix(rgb, thin, worn);
	rgb *= 1.0 - rim * 0.35 * abrasion;
	float s = scratch_field(p, w * scuffs * 0.6, px);
	rgb = mix(rgb, mix(paper, vec3(1.0), 0.4), s);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
