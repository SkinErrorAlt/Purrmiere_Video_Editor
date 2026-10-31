shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform int mode = 0;
uniform float opacity = 1.0;
uniform bool invert = false;
uniform bool first = false;

void fragment() {
	float prev = first ? 0.0 : texture(TEXTURE, UV).a;
	float m = texture(mask_tex, UV).a;
	if (invert) {
		m = 1.0 - m;
	}
	m *= opacity;
	float r;
	if (first) {
		r = (mode == 1) ? 1.0 - m : m;
	} else if (mode == 1) {
		r = prev * (1.0 - m);
	} else if (mode == 2) {
		r = prev * m;
	} else {
		r = max(prev, m);
	}
	COLOR = vec4(vec3(r), r);
}
