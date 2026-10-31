shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 5.0) = 1.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform bool luma_only = false;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 orig = texture(effect_tex, UV);
	vec4 blurred = texture(TEXTURE, UV);
	vec3 diff = orig.rgb - blurred.rgb;
	if (luma_only) {
		diff = vec3(dot(diff, LUMA));
	}
	if (threshold > 0.0) {
		float mag = length(diff);
		float gate = smoothstep(threshold * 0.5, threshold * 1.5, mag);
		diff *= gate;
	}
	vec3 rgb = orig.rgb + diff * amount;
	COLOR = vec4(clamp(rgb, 0.0, max(orig.a, 0.0001)), orig.a);
}
