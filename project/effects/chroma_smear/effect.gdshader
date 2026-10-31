shader_type canvas_item;
render_mode blend_disabled;

uniform float smear : hint_range(0.0, 60.0) = 8.0;
uniform int taps : hint_range(2, 16) = 6;
uniform float direction : hint_range(-180.0, 180.0) = 0.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 w = vec3(0.299, 0.587, 0.114);
	float luma = dot(rgb, w);
	float rad = radians(direction);
	vec2 dir = vec2(cos(rad), sin(rad));
	int n = clamp(taps, 2, 16);
	vec3 chroma = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < n; i++) {
		float t = float(i) / float(n - 1);
		float weight = 1.0 - t;
		vec2 uv = clamp(UV - dir * (smear * max(px_scale, 0.0001) * t) / size, vec2(0.0), vec2(1.0));
		vec4 s = texture(TEXTURE, uv);
		vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		chroma += (sr - vec3(dot(sr, w))) * weight;
		total += weight;
	}
	chroma /= max(total, 0.0001);
	rgb = vec3(luma) + chroma * saturation;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
