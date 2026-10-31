shader_type canvas_item;
render_mode blend_disabled;

uniform int operation : hint_range(0, 1) = 1;
uniform float radius : hint_range(0.0, 40.0) = 3.0;
uniform int channels : hint_range(0, 2) = 0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float r = radius * max(px_scale, 0.0001);
	int n = int(min(ceil(r), 40.0));
	float stp = n > 0 ? r / float(n) : 0.0;
	vec2 px = direction / max(tex_size, vec2(1.0));
	vec4 m = c;
	for (int i = -40; i <= 40; i++) {
		if (i < -n || i > n) { continue; }
		vec4 s = texture(TEXTURE, UV + px * float(i) * stp);
		m = operation == 0 ? min(m, s) : max(m, s);
	}
	vec4 o;
	if (channels == 0) {
		o = vec4(min(m.rgb, vec3(c.a)), c.a);
	} else if (channels == 1) {
		vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
		o = vec4(rgb * m.a, m.a);
	} else {
		o = vec4(min(m.rgb, vec3(m.a)), m.a);
	}
	COLOR = o;
}
