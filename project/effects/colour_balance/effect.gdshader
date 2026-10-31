shader_type canvas_item;
render_mode blend_disabled;

uniform vec3 shadows = vec3(0.0, 0.0, 0.0);
uniform vec3 midtones = vec3(0.0, 0.0, 0.0);
uniform vec3 highlights = vec3(0.0, 0.0, 0.0);
uniform bool preserve_luma = true;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(rgb, LUMA);
	float ws = 1.0 - smoothstep(0.0, 0.5, l);
	float wh = smoothstep(0.5, 1.0, l);
	float wm = 1.0 - ws - wh;
	vec3 shifted = rgb + shadows * ws + midtones * wm + highlights * wh;
	if (preserve_luma) {
		float l2 = dot(shifted, LUMA);
		shifted += vec3(l - l2);
	}
	COLOR = vec4(clamp(shifted, 0.0, 1.0) * c.a, c.a);
}
