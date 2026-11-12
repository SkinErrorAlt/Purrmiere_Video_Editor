shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D coarse_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform int target = 0;
uniform float max_shift : hint_range(0.0, 2.0) = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SPAN = 4.0;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 lin = to_linear(a > 0.0001 ? c.rgb / a : vec3(0.0));
	vec4 loc = texture(TEXTURE, UV);
	vec3 local_c = (loc.rgb - 0.5) * SPAN;
	vec3 gsum = vec3(0.0);
	float gw = 0.0;
	for (int j = 0; j < 6; j++) {
		for (int i = 0; i < 8; i++) {
			vec4 t = texture(coarse_tex, (vec2(float(i), float(j)) + 0.5) / vec2(8.0, 6.0));
			gsum += (t.rgb - 0.5) * SPAN * t.a;
			gw += t.a;
		}
	}
	vec3 global_c = gw > 0.00001 ? gsum / gw : vec3(0.0);
	vec3 goal = target == 0 ? global_c : vec3(0.0);
	float conf = smoothstep(0.01, 0.12, loc.a);
	vec3 delta = (goal - local_c) * clamp(strength, 0.0, 1.0) * conf;
	delta = clamp(delta, vec3(-max_shift), vec3(max_shift));
	vec3 moved = lin * exp2(delta);
	float y0 = dot(lin, LUMA);
	float y1 = dot(moved, LUMA);
	moved *= y0 / max(y1, 0.000001);
	COLOR = vec4(to_display(moved) * a, a);
}
