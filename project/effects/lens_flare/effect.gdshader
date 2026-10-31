shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 position = vec2(0.7, 0.3);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float size : hint_range(0.01, 1.0) = 0.1;
uniform float streak : hint_range(0.0, 2.0) = 0.6;
uniform int ghosts : hint_range(0, 8) = 4;
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.8, 1.0);
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - position) * aspect;
	float r = length(p);
	float core = exp(-r * r / max(size * size, 0.00001));
	float bar = exp(-abs(p.y) / max(size * 0.15, 0.00001)) * exp(-abs(p.x) / max(size * 6.0, 0.00001)) * streak;
	vec3 light = tint.rgb * (core + bar) * brightness;
	int n = clamp(ghosts, 0, 8);
	for (int i = 1; i <= n; i++) {
		float t = float(i) / float(n + 1);
		vec2 gp = (UV - mix(position, vec2(1.0) - position, t * 1.6)) * aspect;
		float gr = length(gp);
		float g = exp(-gr * gr / max(size * size * 0.35, 0.00001));
		vec3 gc = mix(tint.rgb, vec3(0.4, 0.7, 1.0), t);
		light += gc * g * brightness * 0.25;
	}
	rgb += light;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
