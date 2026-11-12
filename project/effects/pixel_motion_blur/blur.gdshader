shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float shutter : hint_range(0.0, 720.0) = 270.0;
uniform int samples : hint_range(4, 48) = 20;
uniform float ignore_under = 0.8;
uniform float max_length = 240.0;
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 limit(vec2 v) {
	float l = length(v);
	float m = max_length * px_scale;
	return l > m ? v * (m / l) : v;
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	vec2 fsz = vec2(textureSize(TEXTURE, 0));
	float s = shutter / 360.0;
	vec2 v = limit(flow_at(TEXTURE, UV)) * s;
	vec2 vmax = v;
	float lmax = length(v);
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		vec2 o = vec2(cos(an), sin(an)) * 2.0 / fsz;
		vec2 w = limit(flow_at(TEXTURE, UV + o)) * s;
		float lw = length(w);
		if (lw > lmax) {
			lmax = lw;
			vmax = w;
		}
	}
	vec4 c0 = texture(effect_tex, UV);
	float gate = ignore_under * px_scale;
	if (lmax < gate) {
		COLOR = c0;
	} else {
		float lv = length(v);
		float j = hash12(FRAGCOORD.xy) - 0.5;
		vec4 acc = c0;
		float wsum = 1.0;
		int n = clamp(samples, 4, 48);
		for (int i = 0; i < 48; i++) {
			if (i >= n) {
				break;
			}
			float t = (float(i) + 0.5 + j) / float(n) - 0.5;
			vec2 off = vmax * t;
			vec2 uv = UV + off / out_size;
			float dist = length(off);
			vec2 vy = limit(flow_at(TEXTURE, uv)) * s;
			float cover_y = clamp(0.5 * length(vy) - dist + 1.0, 0.0, 1.0);
			float cover_x = clamp(0.5 * lv - dist + 1.0, 0.0, 1.0);
			float w = max(cover_x, cover_y);
			acc += texture(effect_tex, uv) * w;
			wsum += w;
		}
		vec4 blurred = acc / wsum;
		float fade = smoothstep(gate, gate * 2.0 + 0.5, lmax);
		COLOR = mix(c0, blurred, fade);
	}
}
