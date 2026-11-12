shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D glob_tex : filter_nearest, repeat_disable;
uniform float speed = 0.13;
uniform float wavelength = 0.035;
uniform float travel = 1.6;

float source_at(int a, vec2 uv, ivec2 fs, vec2 shared_) {
	vec2 g = uv * vec2(fs) - 0.5;
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	float s[4];
	for (int k = 0; k < 4; k++) {
		vec3 c = fp_flow(flow_tex, a, i + ivec2(k % 2, k / 2), fs);
		float sv = clamp((length(c.xy - shared_) - 0.0015) / 0.004, 0.0, 2.0);
		s[k] = sv * sv;
	}
	return mix(mix(s[0], s[1], f.x), mix(s[2], s[3], f.x), f.y);
}

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
	int pairs = fp_pairs(TEXTURE);
	float fps = history_fps;
	float span = float(max(pairs, 1)) / fps;
	float asp = osz.x / osz.y;
	float h = 0.0;
	float omega = 6.2831853 * speed / max(wavelength, 0.005);
	float kmean = 0.0;
	for (int a = 0; a < FP_MAX_PAIRS; a++) {
		if (a >= pairs) {
			break;
		}
		float tau = (float(a) + 0.5) / fps;
		float r = speed * tau;
		kmean += sin(omega * tau) * exp(-tau * 2.2 / max(travel, 0.1)) / sqrt(1.0 + r / 0.02) * (1.0 - smoothstep(span * 0.6, span, tau));
	}
	kmean /= float(max(pairs, 1));
	for (int a = 0; a < FP_MAX_PAIRS; a += 2) {
		if (a >= pairs) {
			break;
		}
		vec2 shared_ = fp_motion(TEXTURE, a);
		float tau = (float(a) + 0.5) / fps;
		float r = speed * tau;
		float ring = 0.0;
		for (int k = 0; k < 8; k++) {
			float an = float(k) * 0.7853982 + float(a) * 0.37;
			vec2 o = vec2(cos(an) / asp, sin(an)) * r;
			ring += source_at(a, UV + o, fs, shared_);
		}
		ring /= 4.0;
		float taper = 1.0 - smoothstep(span * 0.6, span, tau);
		float fade = exp(-tau * 2.2 / max(travel, 0.1)) / sqrt(1.0 + r / 0.02);
		h += ring * (sin(omega * tau) * fade * taper - kmean);
	}
	COLOR = fp_pack2(vec2(h * 0.25, 0.0), 1.0);
}
