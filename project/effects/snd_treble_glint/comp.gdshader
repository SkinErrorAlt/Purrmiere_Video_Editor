shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 3.0) = 1.5;
uniform vec4 colour : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float twinkle : hint_range(0.0, 1.0) = 0.6;
uniform float clip_time = 0.0;

void fragment() {
	vec4 base = texture(effect_tex, UV);
	float a = base.a;
	vec3 rgb = a > 0.0001 ? base.rgb / a : vec3(0.0);
	float hiss = smoothstep(0.4, 0.85, snd_treble) * 0.55;
	float crack = snd_hit * (1.0 - snd_hit_low) * 1.3;
	float g = clamp(hiss + crack, 0.0, 1.6);
	float tw = 1.0 - twinkle * 0.5 + twinkle * 0.5 * sin(clip_time * 23.0 + snd_hit_seed * 40.0);
	vec3 star = texture(TEXTURE, UV).rgb;
	vec3 add = star * colour.rgb * strength * g * tw;
	rgb = rgb + add * (1.0 - rgb * 0.5);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
