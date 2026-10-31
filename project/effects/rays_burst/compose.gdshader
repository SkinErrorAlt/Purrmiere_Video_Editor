shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 colour : source_color = vec4(1.0, 0.95, 0.84, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float white_out : hint_range(0.0, 1.0) = 1.0;

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

void fragment() {
	vec4 c = texture(effect_tex, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 out_px = max(fwidth(UV), vec2(0.000001));
		float e = g * g * (3.0 - 2.0 * g);
		vec3 rays_rgb = tent_b(TEXTURE, UV, out_px * 2.0).rgb;
		float inten = clamp(strength, 0.0, 1.0) * (0.25 + 0.75 * e) * e * 1.6;
		vec3 light = rays_rgb * clamp(colour.rgb, vec3(0.0), vec3(1.0)) * inten;
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec3 o = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * (1.0 - clamp(light, 0.0, 1.0));
		o = mix(o, vec3(1.0), clamp(max(max(light.r, light.g), light.b) - 1.0, 0.0, 1.0) * 0.5);
		float w = clamp(white_out, 0.0, 1.0) * smoothstep(0.72, 1.0, g);
		o = mix(o, mix(vec3(1.0), clamp(colour.rgb, vec3(0.0), vec3(1.0)), 0.3), w);
		float la = clamp(max(max(light.r, light.g), light.b), 0.0, 1.0);
		float oa = max(max(a, la), w);
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
