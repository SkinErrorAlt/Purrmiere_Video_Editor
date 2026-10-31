shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float feather : hint_range(0.0, 100.0) = 8.0;
uniform int position : hint_range(0, 2) = 0;
uniform float shift : hint_range(-50.0, 50.0) = 0.0;
uniform bool show_matte = false;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec4 d = texture(TEXTURE, UV);
	float d_out = unpack16(d.rg);
	float d_in = unpack16(d.ba);
	float s = (d_in - d_out) / k + shift;
	float f = max(feather, 0.0);
	float lo = 0.0;
	if (position == 1) {
		lo = -f * 0.5;
	} else if (position == 2) {
		lo = -f;
	}
	float w = max(f, 1.0 / k);
	float r = clamp((s - lo) / w, 0.0, 1.0);
	float m = r * r * (3.0 - 2.0 * r);
	vec4 orig = texture(effect_tex, UV);
	float a = orig.a;
	float inner = clamp(s * k - 1.0, 0.0, 1.0);
	float oa = clamp(m * mix(1.0, a, inner), 0.0, 1.0);
	vec3 rgb = straight(orig);
	if (a < 0.05 && oa > 0.0001) {
		vec2 size = max(tex_size, vec2(1.0));
		float reach = d_out + 1.5;
		vec3 sum = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 16; i++) {
			float ang = float(i) / 16.0 * 6.28318530718;
			vec2 off = vec2(cos(ang), sin(ang)) * reach / size;
			vec4 sc = texture(effect_tex, clamp(UV + off, vec2(0.0), vec2(1.0)));
			sum += sc.rgb;
			wsum += sc.a;
		}
		if (wsum > 0.0001) {
			rgb = clamp(sum / wsum, 0.0, 1.0);
		}
	}
	if (show_matte) {
		COLOR = vec4(vec3(oa), 1.0);
	} else {
		COLOR = vec4(rgb * oa, oa);
	}
}
