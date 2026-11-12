shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float carry : hint_range(0.2, 1.9) = 1.4;
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform float hold : hint_range(0.0, 0.8) = 0.25;
uniform bool keep_contrast = false;

vec4 block(sampler2D t, int k) {
	ivec2 sz = textureSize(t, 0);
	return texelFetch(t, ivec2(clamp(int((float(k) + 0.5) / 4.0 * float(sz.x)), 0, sz.x - 1), 0), 0);
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec4 b0 = block(TEXTURE, 0);
	float s = floor(b0.r * 63.0 + 0.5);
	float fps = max(history_fps, 1.0);
	float span = min(carry * fps, 57.0);
	if (b0.r > 0.995 || s >= span || strength <= 0.0) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		vec3 x = src.rgb / a;
		vec3 mo = block(TEXTURE, 1).rgb;
		vec3 mn = block(TEXTURE, 2).rgb;
		vec4 sp = block(TEXTURE, 3);
		vec3 so = sp.rgb * 0.5;
		float sn = max(sp.a * 0.5, 0.02);
		float u = s / span;
		float h = clamp(hold, 0.0, 0.9);
		float w = 1.0 - smoothstep(h, 1.0, u);
		w = w * w * (3.0 - 2.0 * w) * strength;
		vec3 gain = keep_contrast ? vec3(1.0) : clamp(so / sn, vec3(0.35), vec3(2.5));
		vec3 y = mo + (x - mn) * gain;
		vec3 outc = mix(x, clamp(y, 0.0, 1.0), w);
		COLOR = vec4(outc * a, a);
	}
}
