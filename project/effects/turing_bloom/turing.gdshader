shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/turing_bloom/sim.gdshaderinc"

uniform float clip_time = 0.0;
uniform float growth : hint_range(0.0, 1.0) = 0.7;
uniform float grow_time : hint_range(0.0, 30.0) = 6.0;
uniform float size : hint_range(6.0, 120.0) = 40.0;
uniform int style : hint_range(0, 3) = 0;
uniform float follow : hint_range(0.0, 1.0) = 0.6;

float reach_now() {
	float g = growth;
	if (grow_time > 0.0) {
		g *= clamp(clip_time / grow_time, 0.0, 1.0);
	}
	return g * 1.1;
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	vec2 px = 1.0 / vec2(sz);
	ivec2 me = clamp(ivec2(UV * vec2(sz)), ivec2(0), sz - 1);
	vec4 hf = texelFetch(TEXTURE, me, 0);
	float d = sim_unpack(hf.rg) * 2.0;
	float r_now = reach_now();
	float inside = (1.0 - smoothstep(r_now - 0.02, r_now + 0.02, d)) * smoothstep(0.0, 0.02, r_now);

	float sigma = max(size / 1080.0 * float(sz.y) / 9.2, 0.6);
	float th = hf.a * 3.14159265;
	vec2 tan_dir = vec2(cos(th), sin(th));
	float an = (style == 2) ? follow * 1.6 : follow * 0.45;
	mat2 shape = mat2(tan_dir, vec2(-tan_dir.y, tan_dir.x)) * mat2(vec2(1.0 + an, 0.0), vec2(0.0, 1.0 / (1.0 + an)));

	float a_sum = hf.b * 0.4;
	float a_w = 0.4;
	float i_sum = hf.b * 0.1;
	float i_w = 0.1;
	for (int ring = 0; ring < 3; ring++) {
		float rr = 0.6 + float(ring) * 0.9;
		float wa = rr * exp(-0.5 * rr * rr);
		float wi = rr * exp(-0.5 * rr * rr / 4.0);
		for (int k = 0; k < 8; k++) {
			float ang = (float(k) + 0.5 * float(ring)) * 0.785398;
			vec2 o = shape * vec2(cos(ang), sin(ang)) * rr * sigma;
			float va = texture(TEXTURE, UV + o * px).b;
			float vi = texture(TEXTURE, UV + o * 2.0 * px).b;
			a_sum += va * wa;
			a_w += wa;
			i_sum += vi * wi;
			i_w += wi;
		}
	}
	float far = 0.0;
	for (int k = 0; k < 8; k++) {
		float ang = float(k) * 0.785398 + 0.39;
		far += texture(TEXTURE, UV + shape * vec2(cos(ang), sin(ang)) * 4.6 * sigma * px).b;
	}
	float A = a_sum / a_w;
	float I = mix(i_sum / i_w, far / 8.0, 0.25);
	float bias = style == 1 ? -0.035 : (style == 3 ? 0.035 : 0.0);
	float p = clamp(hf.b + 5.0 * (A - I) + bias, 0.0, 1.0);
	float rest = 0.5 + (hf.b - 0.5) * 0.15;
	p = mix(rest, p, inside);
	COLOR = vec4(hf.rg, p, hf.a);
}
