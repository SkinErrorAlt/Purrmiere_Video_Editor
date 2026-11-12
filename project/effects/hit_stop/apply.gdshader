shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float hold : hint_range(0.03, 0.3) = 0.13;
uniform float catch_up : hint_range(1.5, 4.0) = 2.0;
uniform float punch : hint_range(0.0, 1.0) = 0.5;
uniform float shake : hint_range(0.0, 1.0) = 0.5;

vec3 lin(vec3 c) {
	return c * c;
}

void fragment() {
	vec4 b0 = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float s = floor(b0.r * 63.0 + 0.5);
	float fps = max(history_fps, 1.0);
	float hf = max(round(hold * fps), 1.0);
	float k = max(catch_up, 1.1);
	float total = hf + hf / (k - 1.0);
	vec4 now = texture(effect_tex, UV);
	if (b0.r > 0.995 || s >= total) {
		COLOR = now;
	} else {
		float behind = s <= hf ? s : max(hf - (s - hf) * (k - 1.0), 0.0);
		vec2 c = b0.ba;
		float str = b0.g;
		float held = s <= hf ? 1.0 : 0.0;
		float tt = (s - hf) / fps;
		float push = held * punch * 0.035 * (0.6 + 0.4 * str) * (1.0 - 0.3 * s / hf);
		vec2 centre = mix(vec2(0.5), c, 0.6);
		vec2 q = (UV - centre) / (1.0 + push) + centre;
		vec2 away = normalize(vec2(0.5) - c + vec2(1e-4));
		float rec = (1.0 - held) * shake * 0.012 * str * exp(-tt * 9.0) * cos(tt * 55.0);
		q += away * rec * vec2(tex_size.y / max(tex_size.x, 1.0), 1.0);
		vec4 pic = behind < 0.01 ? texture(effect_tex, q) : history_between(behind, q, texture(effect_tex, q));
		float a = max(pic.a, 0.0001);
		vec3 l = lin(pic.rgb / a);
		float land = held * exp(-s * 1.2) * punch;
		vec3 m = vec3(dot(l, vec3(0.2126, 0.7152, 0.0722)));
		l = mix(m, l, 1.0 + 0.25 * land) * (1.0 + 0.35 * land);
		l = mix(l, l * l * 2.2, 0.25 * land);
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
