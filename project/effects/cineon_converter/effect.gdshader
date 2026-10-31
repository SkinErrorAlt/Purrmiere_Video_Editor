shader_type canvas_item;
render_mode blend_disabled;

uniform int conversion : hint_range(0, 1) = 0;
uniform float black_point : hint_range(0.0, 1023.0) = 95.0;
uniform float white_point : hint_range(0.0, 1023.0) = 685.0;
uniform float gamma : hint_range(0.1, 5.0) = 1.7;
uniform float rolloff : hint_range(0.0, 100.0) = 20.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float k = 0.002 / 0.6;
	float off = pow(10.0, (black_point - white_point) * k);
	vec3 o;
	if (conversion == 0) {
		vec3 lin = (pow(vec3(10.0), (rgb * 1023.0 - white_point) * k) - off) / max(1.0 - off, 0.0001);
		lin = max(lin, vec3(0.0));
		float knee = 1.0 - rolloff / 200.0;
		if (rolloff > 0.0) {
			vec3 over = max(lin - knee, vec3(0.0));
			lin = min(lin, vec3(knee)) + (1.0 - knee) * (1.0 - exp(-over / max(1.0 - knee, 0.0001)));
		}
		o = pow(lin, vec3(1.0 / max(gamma, 0.01)));
	} else {
		vec3 lin = pow(max(rgb, vec3(0.0)), vec3(gamma));
		vec3 x = max(lin * (1.0 - off) + off, vec3(0.000001));
		o = (white_point + log(x) / 2.302585 / k) / 1023.0;
	}
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
