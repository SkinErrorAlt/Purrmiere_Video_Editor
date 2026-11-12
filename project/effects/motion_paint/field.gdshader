shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform bool camera = true;
uniform float ignore_under = 0.8;
uniform float stroke_len = 14.0;
uniform float motion_len = 6.0;
uniform float max_len = 120.0;

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	vec3 st = vec3(0.0);
	vec2 px = 2.0 * ps / full;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			vec2 uv = UV + vec2(float(i), float(j)) * px * 1.5;
			float l = kit_luma(texture(effect_tex, uv + vec2(px.x, 0.0)).rgb);
			float r = kit_luma(texture(effect_tex, uv - vec2(px.x, 0.0)).rgb);
			float d = kit_luma(texture(effect_tex, uv + vec2(0.0, px.y)).rgb);
			float u = kit_luma(texture(effect_tex, uv - vec2(0.0, px.y)).rgb);
			vec2 g = vec2(l - r, d - u);
			float w = exp(-float(i * i + j * j) / 8.0);
			st += vec3(g.x * g.x, g.y * g.y, g.x * g.y) * w;
		}
	}
	float ang = 0.5 * atan(2.0 * st.z, st.x - st.y) + 1.5707963;
	vec2 tdir = vec2(cos(ang), sin(ang));
	vec2 v = motion_at(flow_tex, UV) - (camera ? kit_global(global_tex, UV) : vec2(0.0));
	float sp = length(v) / ps;
	float mw = smoothstep(ignore_under, ignore_under * 2.0 + 1.0, sp);
	vec2 mdir = sp > 0.001 ? v / length(v) : tdir;
	vec2 dir = normalize(mix(tdir * sign(dot(tdir, mdir) + 1e-4), mdir, mw) + vec2(1e-5, 0.0));
	float len_src = min(stroke_len + motion_len * sp * mw, max_len);
	COLOR = vec4(dir * 0.5 + 0.5, mw, clamp(len_src / max(max_len, 1.0), 0.0, 1.0));
}
