shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform float shine = 0.5;
uniform bool pinned = true;

vec2 disp(sampler2D field, vec2 uv, ivec2 fs) {
	vec2 u = fp_field(field, uv, fs, 0, 0.25);
	float l = length(u);
	if (l > 0.0) {
		u *= 0.05 * tanh(l / 0.05) / l;
	}
	if (pinned) {
		vec2 e = min(uv, 1.0 - uv);
		u *= smoothstep(0.0, 0.12, e.x) * smoothstep(0.0, 0.12, e.y);
	}
	return u;
}

void fragment() {
	ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
	vec2 u = disp(TEXTURE, UV, fs);
	vec4 src = texture(effect_tex, UV);
	if (u == vec2(0.0)) {
		COLOR = src;
	} else {
		vec2 px = 1.0 / vec2(textureSize(effect_tex, 0));
		vec2 h = px * 6.0;
		vec2 ux = (disp(TEXTURE, UV + vec2(h.x, 0.0), fs) - u) / h.x;
		vec2 uy = (disp(TEXTURE, UV + vec2(0.0, h.y), fs) - u) / h.y;
		float jac = (1.0 - ux.x) * (1.0 - uy.y) - ux.y * uy.x;
		vec4 c = texture(effect_tex, clamp(UV - u, vec2(0.0), vec2(1.0)));
		vec3 col = c.rgb;
		float st = clamp(1.0 - jac, -0.6, 0.6);
		col = mix(col, col * 0.78 + 0.22, clamp(-st, 0.0, 1.0) * shine * 0.0);
		col *= 1.0 + st * 0.0;
		float thin = clamp(1.0 / max(jac, 0.2) - 1.0, -0.5, 1.0);
		col = mix(col, mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * 1.12 + 0.05, 0.5), clamp(thin, 0.0, 1.0) * shine);
		col *= 1.0 - clamp(-thin, 0.0, 0.5) * shine * 0.6;
		vec2 slope = vec2(ux.x + uy.x, ux.y + uy.y);
		float sheen = clamp(dot(normalize(vec2(-0.6, -0.8)), slope) * 0.6, -0.3, 0.6);
		col += vec3(sheen) * shine * 0.35;
		COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
	}
}
