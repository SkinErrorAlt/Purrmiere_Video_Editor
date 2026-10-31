shader_type canvas_item;
render_mode blend_disabled;

uniform int screen : hint_range(0, 1) = 0;
uniform int method : hint_range(0, 2) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 replace_colour : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float replace : hint_range(0.0, 1.0) = 1.0;
uniform bool show_spill = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float limit_of(float a, float b) {
	if (method == 1) {
		return max(a, b);
	}
	if (method == 2) {
		return min(a, b);
	}
	return (a + b) * 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	float spill = 0.0;
	vec3 o = rgb;
	float weight = 0.0;
	if (screen == 0) {
		spill = max(rgb.g - limit_of(rgb.r, rgb.b), 0.0) * strength;
		o.g -= spill;
		weight = LUMA.g;
	} else {
		spill = max(rgb.b - limit_of(rgb.r, rgb.g), 0.0) * strength;
		o.b -= spill;
		weight = LUMA.b;
	}
	float lost = spill * weight;
	vec3 tint = replace_colour.rgb / max(dot(replace_colour.rgb, LUMA), 0.02);
	o += tint * lost * replace;
	o = clamp(o, 0.0, 1.0);
	if (show_spill) {
		float s = clamp(spill * 3.0, 0.0, 1.0);
		COLOR = vec4(vec3(s) * c.a, c.a);
	} else {
		COLOR = vec4(o * c.a, c.a);
	}
}
