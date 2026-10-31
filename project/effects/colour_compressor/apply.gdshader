shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int target : hint_range(0, 1) = 0;
uniform vec4 centre : source_color = vec4(0.35, 0.6, 0.25, 1.0);
uniform float width : hint_range(5.0, 180.0) = 50.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float hue_pull : hint_range(0.0, 1.0) = 0.5;
uniform float sat_pull : hint_range(0.0, 1.0) = 0.3;
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

float centre_angle() {
	if (target == 0) {
		return SKIN_ANGLE;
	}
	vec2 cc = chroma_of(centre.rgb);
	return atan(cc.y, cc.x);
}

float wrap_angle(float x) {
	return x - 6.2831853 * floor((x + 3.1415927) / 6.2831853);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float y = dot(rgb, LUMA);
	vec2 cbcr = chroma_of(rgb);
	float m = length(cbcr);
	float ca = centre_angle();
	float ang = atan(cbcr.y, cbcr.x);
	float d = wrap_angle(ang - ca);
	float half_w = radians(width) * 0.5;
	float inner = half_w * (1.0 - softness);
	float w = (1.0 - smoothstep(inner, half_w + 0.0001, abs(d))) * smoothstep(0.015, 0.045, m);
	vec4 st = textureLod(TEXTURE, vec2(0.5), 0.0);
	float mean_m = st.g > 0.5 ? st.r * 0.5 : m;
	float new_ang = ang - d * hue_pull * w;
	float new_m = mix(m, mean_m, sat_pull * w);
	vec3 outc = from_ycc(y, vec2(cos(new_ang), sin(new_ang)) * new_m);
	if (show_mask) {
		outc = vec3(w);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
