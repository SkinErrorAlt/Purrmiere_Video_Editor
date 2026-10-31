shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_2 : filter_linear, repeat_disable;
uniform sampler2D level_3 : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.3;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float stops : hint_range(0.5, 8.0) = 4.0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float bloom : hint_range(0.0, 1.0) = 0.6;
uniform float solid : hint_range(0.0, 1.0) = 1.0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

vec4 tent(sampler2D tex, vec2 uv, vec2 px) {
	vec4 s = texture(tex, uv) * 4.0;
	s += texture(tex, uv + px * vec2(-1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, -1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, 1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(-1.0, -1.0));
	s += texture(tex, uv + px * vec2(1.0, -1.0));
	s += texture(tex, uv + px * vec2(-1.0, 1.0));
	s += texture(tex, uv + px * vec2(1.0, 1.0));
	return s / 16.0;
}

vec4 tent_b(sampler2D tex, vec2 uv, vec2 px) {
	vec4 s = texture(tex, uv) * 4.0;
	s += texture(tex, uv + px * vec2(-1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, -1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, 1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(-1.0, -1.0));
	s += texture(tex, uv + px * vec2(1.0, -1.0));
	s += texture(tex, uv + px * vec2(-1.0, 1.0));
	s += texture(tex, uv + px * vec2(1.0, 1.0));
	return s / 16.0;
}

vec3 shoulder(vec3 x) {
	vec3 over = max(x - 0.75, vec3(0.0));
	return min(x, vec3(0.75)) + 0.25 * (1.0 - exp(-over / 0.25));
}

vec3 straight(vec4 p) {
	return p.a > 0.0001 ? p.rgb / p.a : vec3(0.0);
}

void fragment() {
	vec2 out_px = max(fwidth(UV), vec2(0.000001));
	vec4 c = texture(effect_tex, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		float e = pow(g, 1.4);
		float a = c.a;
		vec3 rgb = straight(c);
		float gain = exp2(clamp(stops, 0.5, 8.0) * e);
		vec3 tint = mix(vec3(1.0), clamp(colour.rgb, vec3(0.0), vec3(1.0)), e);
		vec3 lit = rgb * gain * tint + vec3(0.02) * (gain - 1.0) * tint;
		vec4 b2 = tent(level_2, UV, out_px * 4.0);
		vec4 b3 = tent(level_3, UV, out_px * 8.0);
		vec4 b4 = tent_b(TEXTURE, UV, out_px * 16.0);
		vec4 wide = b2 * 0.25 + b3 * 0.35 + b4 * 0.4;
		vec3 wide_rgb = straight(wide) * gain * tint;
		vec3 glow_rgb = max(wide_rgb - 0.8, vec3(0.0)) * clamp(bloom, 0.0, 1.0) * 0.6;
		vec3 o = shoulder(lit + glow_rgb);
		o = mix(rgb, o, clamp(g * 12.0, 0.0, 1.0));
		float glow_a = clamp(dot(glow_rgb, vec3(0.3333)), 0.0, 1.0) * wide.a;
		float w = clamp(solid, 0.0, 1.0) * smoothstep(0.7, 1.0, g);
		o = mix(o, clamp(colour.rgb, vec3(0.0), vec3(1.0)), w);
		float oa = max(max(a, glow_a), w);
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
