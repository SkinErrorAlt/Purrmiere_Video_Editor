shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/interp_flow.gdshaderinc"
#include "res://engine/purrframes/purrframes_colour.gdshaderinc"

uniform sampler2D a_tex : filter_linear, repeat_disable;
uniform sampler2D b_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D given_tex : filter_linear, repeat_disable;
uniform vec2 size = vec2(2.0);
uniform vec2 flow_size = vec2(2.0);
uniform float w = 0.0;
uniform float fall_lo = 0.08;
uniform float fall_hi = 0.25;
uniform bool use_given = false;
uniform int given_matrix = 0;

void fragment() {
	if (use_given) {
		COLOR = texture(given_tex, UV);
		COLOR.rgb = given_matrix == 0 ? COLOR.rgb : purrframes_from_601(COLOR.rgb, given_matrix);
	} else {
		vec2 x = floor(UV * size) + 0.5;
		vec2 f = x * flow_size / size - 0.5;
		vec2 f0 = floor(f);
		vec2 fr = f - f0;
		ivec2 i0 = ivec2(f0);
		ivec2 hi = ivec2(flow_size) - ivec2(1);
		vec2 v00 = flow_decode(texelFetch(flow_tex, clamp(i0, ivec2(0), hi), 0));
		vec2 v10 = flow_decode(texelFetch(flow_tex, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0));
		vec2 v01 = flow_decode(texelFetch(flow_tex, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0));
		vec2 v11 = flow_decode(texelFetch(flow_tex, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0));
		vec2 d = mix(mix(v00, v10, fr.x), mix(v01, v11, fr.x), fr.y);
		vec4 a1 = texture(a_tex, (x - w * d) / size);
		vec4 b1 = texture(b_tex, (x + (1.0 - w) * d) / size);
		vec4 a0 = texture(a_tex, x / size);
		vec4 b0 = texture(b_tex, x / size);
		vec4 mc = mix(a1, b1, w);
		vec4 plain = mix(a0, b0, w);
		vec3 e = abs(a1.rgb - b1.rgb);
		float k = smoothstep(fall_lo, fall_hi, max(e.r, max(e.g, e.b)));
		COLOR = mix(mc, plain, k);
	}
}
