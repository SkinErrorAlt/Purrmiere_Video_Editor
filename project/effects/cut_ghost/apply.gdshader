shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)
uniform int lingers : hint_range(0, 1) = 0;
uniform float linger : hint_range(0.2, 1.9) = 1.2;
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float drift : hint_range(0.0, 1.0) = 0.4;
uniform float soften : hint_range(0.0, 1.0) = 0.5;

vec3 lin(vec3 c) {
	return c * c;
}

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 b0 = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float s = floor(b0.r * 63.0 + 0.5);
	float fps = max(history_fps, 1.0);
	float span = min(linger * fps, 57.0);
	int age = int(s) + 1;
	if (b0.r > 0.995 || s >= span || strength <= 0.0 || !history_has(age)) {
		COLOR = src;
	} else {
		float u = s / span;
		float a = max(src.a, 0.0001);
		vec3 now = lin(src.rgb / a);
		float z = 1.0 + drift * 0.06 * u;
		vec2 q = (UV - 0.5) / z + 0.5;
		vec2 px = uv_px * px_out;
		float r = soften * u * 10.0;
		vec3 g = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 7; i++) {
			float ang = float(i) * 2.39996 + 0.5;
			vec2 off = i == 0 ? vec2(0.0) : vec2(cos(ang), sin(ang)) * r * sqrt(float(i) / 6.0) * px;
			vec4 h = history_frame(age, q + off, src);
			float w = i == 0 ? 2.0 : 1.0;
			g += lin(h.rgb / max(h.a, 0.0001)) * w;
			wsum += w;
		}
		g /= wsum;
		vec3 outc;
		if (lingers == 0) {
			float y = sqrt(dot(g, vec3(0.2126, 0.7152, 0.0722)));
			float thr = mix(-0.15, 1.05, pow(u, 0.8));
			float keep = smoothstep(thr, thr + 0.3, y) * (1.0 - u * u) * strength;
			vec3 gk = g * keep;
			outc = mix(max(now, gk), 1.0 - (1.0 - now) * (1.0 - gk), 0.35);
		} else {
			float k = (1.0 - smoothstep(0.0, 1.0, u)) * strength;
			outc = mix(now, g, k * 0.85);
		}
		COLOR = vec4(sqrt(clamp(outc, 0.0, 1.0)) * a, a);
	}
}
