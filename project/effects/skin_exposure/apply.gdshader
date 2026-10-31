shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float target : hint_range(20.0, 90.0) = 55.0;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float max_stops : hint_range(0.0, 3.0) = 1.5;
uniform float skin_range : hint_range(10.0, 90.0) = 40.0;
uniform bool show_mask = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SKIN_ANGLE = 2.1467;

vec2 chroma_of(vec3 rgb) {
	float y = dot(rgb, LUMA);
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
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
	float hue_w = 1.0 - smoothstep(half_w * 0.5, half_w + 0.0001, d);
	float sat_w = smoothstep(0.003, 0.009, m) * (1.0 - smoothstep(0.22, 0.32, m)) * smoothstep(0.07, 0.15, m / max(y, 0.01));
	float lum_w = smoothstep(0.02, 0.05, y) * (1.0 - smoothstep(0.93, 0.99, y));
	return hue_w * sat_w * lum_w;
}

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 st = textureLod(TEXTURE, vec2(0.5), 0.0);
	float have = st.r * st.r;
	float cover = smoothstep(0.02, 0.1, st.g);
	float want = to_linear(vec3(target * 0.01)).r;
	float stops = have > 0.00001 ? clamp(log2(want / have) * strength, -max_stops, max_stops) * cover : 0.0;
	vec3 outc = to_display(to_linear(rgb) * exp2(stops));
	if (show_mask) {
		float w = skin_weight(rgb);
		outc = mix(vec3(dot(rgb, LUMA) * 0.3), vec3(1.0, 0.55, 0.35), w);
	}
	COLOR = vec4(outc * a, a);
}
