shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 2) = 2;
uniform sampler2D picture : filter_linear, hint_default_black;
uniform float max_blur : hint_range(0.0, 80.0) = 12.0;
uniform bool invert = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	float m;
	if (source == 0) {
		m = dot(texture(picture, UV).rgb, vec3(0.299, 0.587, 0.114));
	} else if (source == 1) {
		vec4 t = texture(TEXTURE, UV);
		m = t.a > 0.0001 ? dot(t.rgb / t.a, vec3(0.299, 0.587, 0.114)) : 0.0;
	} else {
		m = UV.y;
	}
	if (invert) { m = 1.0 - m; }
	float r = max_blur * max(px_scale, 0.0001) * clamp(m, 0.0, 1.0);
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = texture(TEXTURE, UV);
	for (int i = 1; i < 48; i++) {
		float fi = float(i);
		float th = fi * 2.39996323;
		sum += texture(TEXTURE, UV + vec2(cos(th), sin(th)) * sqrt(fi / 48.0) * r * px);
	}
	COLOR = sum / 48.0;
}
