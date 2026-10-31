shader_type canvas_item;
render_mode blend_disabled;

uniform float radius : hint_range(0.0, 80.0) = 14.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.45;
uniform float intensity : hint_range(0.0, 2.0) = 0.7;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 px = vec2(radius * max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	float dark = 0.0;
	vec3 soft = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		float fi = float(i);
		float th = fi * 2.39996323;
		vec4 s = texture(TEXTURE, UV + vec2(cos(th), sin(th)) * sqrt((fi + 0.5) / 32.0) * px);
		vec3 sc = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		float l = dot(sc, vec3(0.2126, 0.7152, 0.0722));
		dark += 1.0 - smoothstep(threshold - 0.15, threshold + 0.15, l);
		soft += sc;
	}
	dark /= 32.0;
	soft /= 32.0;
	float k = clamp(dark * intensity, 0.0, 1.0);
	vec3 o = mix(rgb, min(rgb, soft), k) * (1.0 - 0.5 * k);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
