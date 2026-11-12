shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform int keep_sharp = 0;
uniform float blur = 14.0;
uniform float bokeh = 0.5;
uniform float haze = 0.0;
uniform vec4 haze_colour : source_color = vec4(0.80, 0.84, 0.90, 1.0);

float soft_of(sampler2D mt, vec2 uv) {
	float m = texture(mt, uv).r;
	return keep_sharp == 0 ? 1.0 - m : m;
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 src = texture(effect_tex, UV);
	float soft = soft_of(TEXTURE, UV);
	float rmax = blur * ps;
	float rp = rmax * soft;
	vec4 outc = src;
	if (rp > 0.6) {
		vec3 acc = vec3(0.0);
		float aacc = 0.0;
		float ws = 0.0;
		float ga = 2.39996323;
		float rot = 0.0;
		for (int i = 0; i < 96; i++) {
			float fi = (float(i) + 0.5) / 96.0;
			float rr = sqrt(fi) * rp;
			float an = float(i) * ga + rot;
			vec2 o = vec2(cos(an), sin(an)) * rr;
			vec2 uv = UV + o / out_size;
			vec4 c = texture(effect_tex, uv);
			float rq = rmax * soft_of(TEXTURE, uv);
			float reach = clamp(rq - rr + 1.0, 0.0, 1.0);
			vec3 lin = c.rgb * c.rgb;
			float l = kit_luma(c.rgb);
			float hw = 1.0 + bokeh * 14.0 * pow(max(l - 0.62, 1e-6) / 0.38, 2.0);
			float w = reach * hw;
			acc += lin * w;
			aacc += c.a * w;
			ws += w;
		}
		vec3 lin0 = src.rgb * src.rgb;
		float w0 = 0.15;
		acc += lin0 * w0;
		aacc += src.a * w0;
		ws += w0;
		outc = vec4(sqrt(max(acc / ws, 0.0)), aacc / ws);
	}
	if (haze > 0.0) {
		float h = haze * soft * 0.6;
		outc.rgb = mix(outc.rgb, haze_colour.rgb * outc.a, h);
	}
	COLOR = outc;
}
