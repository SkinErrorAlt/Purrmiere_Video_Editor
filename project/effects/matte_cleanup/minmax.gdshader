shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool use_max = false;
uniform float span = 0.0;

void fragment() {
	float r = min(abs(span) * max(px_scale, 0.0001), 40.0);
	int n = int(ceil(r));
	vec2 step_uv = direction / max(tex_size, vec2(1.0));
	float m = texture(TEXTURE, UV).r;
	for (int i = 1; i <= 40; i++) {
		if (i > n) {
			break;
		}
		float fi = float(i);
		float w = clamp(r - fi + 1.0, 0.0, 1.0);
		float a = texture(TEXTURE, clamp(UV + step_uv * fi, vec2(0.0), vec2(1.0))).r;
		float b = texture(TEXTURE, clamp(UV - step_uv * fi, vec2(0.0), vec2(1.0))).r;
		float t = use_max ? max(a, b) : min(a, b);
		float next = use_max ? max(m, t) : min(m, t);
		m = mix(m, next, w);
	}
	COLOR = vec4(m, m, m, m);
}
