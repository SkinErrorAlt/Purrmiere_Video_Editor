shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.7;
uniform float radius : hint_range(0.0, 80.0) = 16.0;
uniform float strength : hint_range(0.0, 4.0) = 0.8;
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.25, 1.0);
uniform int taps : hint_range(4, 24) = 10;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	int n = clamp(taps, 4, 24);
	float step_r = radius * max(px_scale, 0.0001);
	vec3 halo = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < n; i++) {
		float ang = float(i) / float(n) * 6.28318530718;
		vec2 off = vec2(cos(ang), sin(ang)) * step_r / size;
		vec4 s = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
		vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		float bright = max(dot(sr, w) - threshold, 0.0) / max(1.0 - threshold, 0.0001);
		halo += sr * bright;
		total += 1.0;
	}
	halo /= max(total, 0.0001);
	rgb += halo * tint.rgb * strength * tint.a;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
