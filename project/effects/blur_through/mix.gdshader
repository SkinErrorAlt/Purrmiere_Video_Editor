shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D level_1 : filter_linear, repeat_disable;
uniform sampler2D level_2 : filter_linear, repeat_disable;
uniform sampler2D level_3 : filter_linear, repeat_disable;
uniform sampler2D level_4 : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.5;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float amount : hint_range(0.05, 1.0) = 0.6;
uniform float glow : hint_range(0.0, 1.0) = 0.35;
uniform float brighten : hint_range(0.0, 1.0) = 0.0;

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

vec4 level(int k, vec2 uv, vec2 out_px, sampler2D top) {
	vec2 px = out_px * pow(2.0, float(k));
	if (k <= 0) {
		return texture(effect_tex, uv);
	}
	if (k == 1) {
		return tent(level_1, uv, px);
	}
	if (k == 2) {
		return tent(level_2, uv, px);
	}
	if (k == 3) {
		return tent(level_3, uv, px);
	}
	if (k == 4) {
		return tent(level_4, uv, px);
	}
	return tent_b(top, uv, px);
}

void fragment() {
	vec2 out_px = max(fwidth(UV), vec2(0.000001));
	vec4 c = texture(effect_tex, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		float e = g * g * (3.0 - 2.0 * g);
		float out_h = 1.0 / out_px.y;
		float radius = clamp(amount, 0.05, 1.0) * 0.09 * out_h * e;
		float lv = clamp(log2(max(radius, 1.0)) * 1.1, 0.0, 5.0);
		int lo = int(floor(lv));
		float fr = lv - float(lo);
		vec4 wide = level(min(lo + 1, 5), UV, out_px, TEXTURE);
		vec4 b = mix(level(lo, UV, out_px, TEXTURE), wide, fr);
		float a = b.a;
		vec3 rgb = a > 0.0001 ? b.rgb / a : vec3(0.0);
		vec3 wide_rgb = wide.a > 0.0001 ? wide.rgb / wide.a : vec3(0.0);
		float wl = dot(wide_rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 bloom = wide_rgb * smoothstep(0.45, 1.0, wl) * clamp(glow, 0.0, 1.0) * 1.6 * e;
		rgb = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * (1.0 - clamp(bloom, 0.0, 1.0));
		float lift = clamp(brighten, 0.0, 1.0) * e * e;
		rgb = mix(rgb, vec3(1.0), lift * 0.85);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
