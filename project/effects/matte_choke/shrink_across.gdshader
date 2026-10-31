shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float choke : hint_range(-40.0, 40.0) = 1.0;

void fragment() {
	bool grow = choke < 0.0;
	float r = min(abs(choke) * px_scale, 40.0);
	vec3 widths = vec3(r, r * 0.78, r * 0.45);
	float flip = grow ? 1.0 : 0.0;
	float centre = abs(flip - texture(TEXTURE, UV).a);
	vec3 m = vec3(centre);
	float px = 1.0 / max(tex_size.x, 1.0);
	int n = int(ceil(r));
	for (int i = 1; i <= 40; i++) {
		if (i > n) {
			break;
		}
		float fi = float(i);
		float right = texture(TEXTURE, clamp(UV + vec2(px * fi, 0.0), vec2(0.0), vec2(1.0))).a;
		float left = texture(TEXTURE, clamp(UV - vec2(px * fi, 0.0), vec2(0.0), vec2(1.0))).a;
		float t = min(abs(flip - right), abs(flip - left));
		vec3 w = clamp(widths - vec3(fi) + 1.0, 0.0, 1.0);
		m = mix(m, min(m, vec3(t)), w);
	}
	COLOR = vec4(m, centre);
}
