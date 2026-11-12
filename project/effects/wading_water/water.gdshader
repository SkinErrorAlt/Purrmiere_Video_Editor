shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float height = 1.0;
uniform float glint = 0.5;
uniform vec4 tint : source_color = vec4(0.86, 0.95, 1.0, 1.0);

float hraw(sampler2D t, ivec2 p, ivec2 sz) {
	return fp_unpack2(texelFetch(t, clamp(p, ivec2(0), sz - ivec2(1)), 0), 1.0).x;
}

float hat(sampler2D t, vec2 uv) {
	ivec2 sz = textureSize(t, 0);
	vec2 g = uv * vec2(sz) - 0.5;
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hraw(t, i, sz), hraw(t, i + ivec2(1, 0), sz), f.x), mix(hraw(t, i + ivec2(0, 1), sz), hraw(t, i + ivec2(1, 1), sz), f.x), f.y);
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec2 hs = 1.0 / vec2(textureSize(TEXTURE, 0));
	float h0 = hat(TEXTURE, UV);
	float hx = hat(TEXTURE, UV + vec2(hs.x, 0.0)) - hat(TEXTURE, UV - vec2(hs.x, 0.0));
	float hy = hat(TEXTURE, UV + vec2(0.0, hs.y)) - hat(TEXTURE, UV - vec2(0.0, hs.y));
	vec2 slope = vec2(hx, hy) * height;
	if (slope == vec2(0.0) && h0 == 0.0) {
		COLOR = src;
	} else {
		vec2 uv = UV - slope * 0.035;
		vec3 col = texture(effect_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
		float wet = clamp(length(slope) * 30.0, 0.0, 1.0);
		col *= mix(vec3(1.0), tint.rgb, wet);
		vec3 n = normalize(vec3(-slope * 10.0, 1.0));
		vec3 hv = normalize(vec3(-0.3, -0.6, 1.0) + vec3(0.0, 0.0, 1.0));
		float sp = pow(max(dot(n, hv), 0.0), 40.0) - pow(hv.z, 40.0);
		col += vec3(clamp(sp, 0.0, 1.0)) * glint * 0.9;
		col *= 1.0 + clamp(dot(n.xy, normalize(vec2(-0.3, -0.6))) * 2.5, -0.25, 0.25);
		COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
	}
}
