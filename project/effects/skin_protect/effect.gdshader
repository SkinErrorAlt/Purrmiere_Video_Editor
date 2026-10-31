shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform int keep : hint_range(0, 2) = 0;
uniform float skin_range : hint_range(10.0, 90.0) = 40.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float light_low : hint_range(0.0, 0.5) = 0.08;
uniform float light_high : hint_range(0.5, 1.0) = 0.97;
uniform bool show_mask = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SKIN_ANGLE = 2.1467;

vec2 chroma_of(vec3 rgb) {
	float y = dot(rgb, LUMA);
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

vec3 from_ycc(float y, vec2 cbcr) {
	float r = y + 1.5748 * cbcr.y;
	float b = y + 1.8556 * cbcr.x;
	float g = (y - 0.2126 * r - 0.0722 * b) / 0.7152;
	return vec3(r, g, b);
}

float wrap_angle(float x) {
	return x - 6.2831853 * floor((x + 3.1415927) / 6.2831853);
}

float skin_weight(vec3 rgb) {
	float y = dot(rgb, LUMA);
	vec2 cbcr = chroma_of(rgb);
	float m = length(cbcr);
	float d = abs(wrap_angle(atan(cbcr.y, cbcr.x) - SKIN_ANGLE));
	float half_w = radians(skin_range) * 0.5;
	float hue_w = 1.0 - smoothstep(half_w * (1.0 - softness), half_w + 0.0001, d);
	float sat_w = smoothstep(0.012, 0.035, m) * (1.0 - smoothstep(0.22, 0.32, m));
	float soft_l = 0.02 + 0.08 * softness;
	float lum_w = smoothstep(light_low - soft_l, light_low + soft_l, y) * (1.0 - smoothstep(light_high - soft_l, light_high + soft_l, y));
	return hue_w * sat_w * lum_w;
}

void fragment() {
	vec4 g = texture(TEXTURE, UV);
	float a = g.a;
	vec3 graded = a > 0.0001 ? clamp(g.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 s = texture(source_tex, UV);
	vec3 src = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : graded;
	float w = skin_weight(src) * step(0.0001, s.a);
	vec3 back = src;
	if (keep == 0) {
		float yg = dot(graded, LUMA);
		float ys = dot(src, LUMA);
		float ratio = clamp(yg / max(ys, 0.002), 0.25, 4.0);
		back = from_ycc(yg, chroma_of(src) * ratio);
	} else if (keep == 1) {
		vec2 gc = chroma_of(graded);
		vec2 sc = chroma_of(src);
		float sm = length(sc);
		vec2 dir = sm > 0.0001 ? sc / sm : vec2(0.0);
		back = from_ycc(dot(graded, LUMA), dir * length(gc));
	}
	vec3 outc = mix(graded, clamp(back, 0.0, 1.0), w * amount);
	if (show_mask) {
		outc = vec3(w);
	}
	COLOR = vec4(outc * a, a);
}
