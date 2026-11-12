shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float milky : hint_range(0.0, 0.6) = 0.2;
uniform float blotch : hint_range(0.0, 1.0) = 0.55;
uniform vec4 chem : source_color = vec4(0.68, 0.74, 0.66, 1.0);
uniform float corners : hint_range(0.0, 1.0) = 0.6;
uniform float snap : hint_range(0.0, 1.0) = 0.7;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	float swap = smoothstep(0.0, 0.1, p);
	vec4 start = mix(a, chem, swap);
	float m = clamp(milky, 0.0, 0.6);
	float dev = clamp((p - m) / max(1.0 - m, 0.0001), 0.0, 1.0);
	float edge_help = 1.0 - clamp(length((uv - 0.5) * vec2(tr_ratio(), 1.0)) / (0.5 * length(vec2(tr_ratio(), 1.0))), 0.0, 1.0);
	float slow = mix(0.0, edge_help, clamp(corners, 0.0, 1.0));
	float patch = (tr_fbm(uv * 3.4 + 7.0) - 0.5) * blotch;
	float local = clamp(dev * 1.45 - slow * 0.35 + patch * 0.4, 0.0, 1.0);
	float luma = dot(b.rgb, vec3(0.2126, 0.7152, 0.0722));
	float darks_first = clamp(local * 1.6 - luma * 0.55, 0.0, 1.0);
	vec3 grey = vec3(luma);
	vec3 arriving = mix(chem.rgb, grey, clamp(darks_first * 1.3, 0.0, 1.0));
	float colour_in = smoothstep(0.45, 1.0, local);
	vec3 shown = mix(arriving, b.rgb, colour_in);
	float contrast = mix(0.55, 1.0, smoothstep(0.55, 1.0, local));
	shown = mix(vec3(0.5), shown, mix(1.0, contrast, snap));
	float settle = smoothstep(0.93, 1.0, p);
	vec3 outc = mix(mix(start.rgb, shown, smoothstep(0.0, 0.14, p)), b.rgb, settle);
	return vec4(outc, 1.0);
}

void fragment() {
	COLOR = transition(UV);
}
