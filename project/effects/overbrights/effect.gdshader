shader_type canvas_item;
render_mode blend_disabled;

uniform int check : hint_range(0, 5) = 0;
uniform int show : hint_range(0, 2) = 0;
uniform float over_at : hint_range(0.8, 1.0) = 1.0;
uniform float under_at : hint_range(0.0, 0.2) = 0.0;
uniform vec4 over_colour : source_color = vec4(1.0, 0.15, 0.55, 1.0);
uniform vec4 under_colour : source_color = vec4(0.15, 0.45, 1.0, 1.0);
uniform int rest : hint_range(0, 3) = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float SLACK = 0.0015;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float hi = over_at - SLACK;
	float lo = under_at + SLACK;
	bool want_over = show != 2;
	bool want_under = show != 1;
	vec3 base = clamp(rgb, 0.0, 1.0);
	float l = dot(base, LUMA);
	vec3 shown = base;
	if (rest == 0) {
		shown = vec3(0.12 + l * 0.3);
	} else if (rest == 2) {
		shown = vec3(0.4);
	} else if (rest == 3) {
		shown = vec3(0.0);
	}
	float out_a = a;
	if (check == 0) {
		vec3 over = step(vec3(hi), rgb);
		vec3 under = 1.0 - step(vec3(lo), rgb);
		float any_over = max(over.r, max(over.g, over.b));
		float any_under = max(under.r, max(under.g, under.b));
		float all_over = min(over.r, min(over.g, over.b));
		float all_under = min(under.r, min(under.g, under.b));
		if (want_over && any_over > 0.5) {
			shown = all_over > 0.5 ? over_colour.rgb : over;
		} else if (want_under && any_under > 0.5) {
			shown = all_under > 0.5 ? under_colour.rgb : under_colour.rgb * (0.35 + 0.65 * under);
		}
	} else {
		float v = l;
		if (check == 2) {
			v = rgb.r;
		} else if (check == 3) {
			v = rgb.g;
		} else if (check == 4) {
			v = rgb.b;
		} else if (check == 5) {
			v = a;
			out_a = 1.0;
			shown = mix(vec3(0.4), shown, a);
		}
		if (want_over && v >= hi) {
			shown = over_colour.rgb;
		} else if (want_under && v <= lo) {
			shown = under_colour.rgb;
		}
	}
	COLOR = vec4(clamp(shown, 0.0, 1.0) * out_a, out_a);
}
