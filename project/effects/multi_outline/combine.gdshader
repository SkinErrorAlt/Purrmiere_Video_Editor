shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform int position : hint_range(0, 2) = 0;
uniform float width_1 : hint_range(0.0, 40.0) = 6.0;
uniform vec4 colour_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_2 = true;
uniform float gap_2 : hint_range(0.0, 20.0) = 0.0;
uniform float width_2 : hint_range(0.0, 40.0) = 3.0;
uniform vec4 colour_2 : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform bool use_3 = false;
uniform float gap_3 : hint_range(0.0, 20.0) = 0.0;
uniform float width_3 : hint_range(0.0, 40.0) = 4.0;
uniform vec4 colour_3 : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float softness : hint_range(0.0, 4.0) = 0.75;
uniform float glow : hint_range(0.0, 40.0) = 0.0;
uniform bool hide_fill = false;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

float band(float u, float lo, float hi, float soft) {
	if (hi <= lo) {
		return 0.0;
	}
	return smoothstep(lo - soft, lo + soft, u) * (1.0 - smoothstep(hi - soft, hi + soft, u));
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec4 d = texture(TEXTURE, UV);
	float u = (unpack16(d.rg) - unpack16(d.ba)) / k;
	float soft = max(softness, 0.35);
	float start = 0.0;
	if (position == 1) {
		start = -width_1 * 0.5;
	} else if (position == 2) {
		start = -width_1;
	}
	float e1 = start + width_1;
	float s2 = e1 + gap_2;
	float e2 = use_2 ? s2 + width_2 : e1;
	float s3 = e2 + gap_3;
	float e3 = use_3 ? s3 + width_3 : e2;
	float lo1 = position == 0 ? -soft : start;
	float c1 = band(u, lo1, e1, soft) * colour_1.a;
	float c2 = use_2 ? band(u, s2, e2, soft) * colour_2.a : 0.0;
	float c3 = use_3 ? band(u, s3, e3, soft) * colour_3.a : 0.0;
	vec4 rings = vec4(colour_1.rgb * c1, c1);
	rings = over(vec4(colour_2.rgb * c2, c2), rings);
	rings = over(vec4(colour_3.rgb * c3, c3), rings);
	if (glow > 0.0) {
		vec3 gc = use_3 ? colour_3.rgb : (use_2 ? colour_2.rgb : colour_1.rgb);
		float t = clamp((u - e3) / max(glow, 0.001), 0.0, 1.0);
		float g = u > e3 - soft ? (1.0 - t) * (1.0 - t) * 0.8 : 0.0;
		rings = over(rings, vec4(gc * g, g));
	}
	vec4 pic = texture(effect_tex, UV);
	if (hide_fill) {
		pic = vec4(0.0);
	}
	vec4 o = position == 0 ? over(pic, rings) : over(rings, pic);
	COLOR = clamp(o, 0.0, 1.0);
}
