shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.55;
uniform float reach : hint_range(0.0, 400.0) = 80.0;
uniform int taps : hint_range(2, 32) = 16;
uniform bool vertical_sort = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec2 dir = vertical_sort ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
	int n = clamp(taps, 2, 32);
	vec3 best = rgb;
	float best_l = dot(rgb, w);
	for (int i = 1; i <= n; i++) {
		float t = float(i) / float(n);
		vec2 uv = clamp(UV - dir * (reach * max(px_scale, 0.0001) * t) / size, vec2(0.0), vec2(1.0));
		vec4 s = texture(TEXTURE, uv);
		vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		float sl = dot(sr, w);
		if (sl > threshold && sl > best_l) {
			best_l = sl;
			best = sr;
		}
	}
	rgb = best_l > threshold ? best : rgb;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
