shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D glob_tex : filter_nearest, repeat_disable;
uniform sampler2D resid_tex : filter_nearest, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform float bounce = 1.5;
uniform float settle = 1.2;
uniform float drag = 1.0;
uniform float recover = 1.5;
uniform float press = 0.06;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
	if (p.y == fs.y && p.x < 2) {
		vec4 r = fp_respond(glob_tex, fp_pairs(glob_tex), history_fps, fp_spring(bounce, settle), vec2(1.0));
		COLOR = p.x == 0 ? fp_pack2(r.xy, FP_XRANGE) : fp_pack2(r.zw, FP_VRANGE);
	} else if (p.x >= fs.x * 2 || p.y >= fs.y) {
		COLOR = vec4(0.0);
	} else {
		int which = p.x / fs.x;
		ivec2 cell = p - ivec2(which * fs.x, 0);
		int pairs = fp_pairs(glob_tex);
		float fps = history_fps;
		float span = float(max(pairs, 1)) / fps;
		vec2 wz = fp_spring(bounce, settle);
		float wd = sqrt(max(wz.x * wz.x - wz.y * wz.y, 0.04));
		vec2 u = vec2(0.0);
		float dent = 0.0;
		float now = 0.0;
		for (int a = 0; a < FP_MAX_PAIRS; a++) {
			if (a >= pairs) {
				break;
			}
			vec3 f = fp_flow(flow_tex, a, cell, fs) * 0.5;
			f += (fp_flow(flow_tex, a, cell + ivec2(1, 0), fs) + fp_flow(flow_tex, a, cell - ivec2(1, 0), fs) + fp_flow(flow_tex, a, cell + ivec2(0, 1), fs) + fp_flow(flow_tex, a, cell - ivec2(0, 1), fs)) * 0.125;
			vec2 shared_ = fp_motion(resid_tex, a);
			f.xy -= shared_;
			if (length(f.xy) < FP_FRANGE / 127.0 * 1.5) {
				f.xy = vec2(0.0);
			}
			float tau = (float(a) + 0.5) / fps;
			float taper = 1.0 - smoothstep(span * 0.6, span, tau);
			if (which == 0) {
				float g = exp(-wz.y * tau) * sin(wd * tau) / wd;
				u += f.xy * (wz.x * wz.x * 0.25 * drag * g * taper);
			} else {
				float r = (1.0 - exp(-tau / 0.07)) * exp(-tau / max(recover, 0.05));
				float e = clamp((length(f.xy) - 0.0015) / 0.004, 0.0, 1.5) + f.z * 0.1;
				dent += e * r * taper;
				if (a < 2) {
					now += e * 0.5;
				}
			}
		}
		if (which == 0) {
			COLOR = fp_pack2(u, 0.25);
		} else {
			float d = 1.0 - exp(-dent * press * 4.0);
			COLOR = fp_pack2(vec2(d, now), 1.0);
		}
	}
}
