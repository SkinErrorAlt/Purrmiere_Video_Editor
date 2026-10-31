shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 point = vec2(0.5, 0.5);
uniform float sample_radius : hint_range(0.0, 50.0) = 4.0;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform bool keep_alpha = true;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 r = vec2(sample_radius * max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	vec4 s = texture(TEXTURE, point);
	for (int i = 0; i < 12; i++) {
		float t = float(i) * 0.5235988;
		vec2 d = vec2(cos(t), sin(t)) * (i % 2 == 0 ? 1.0 : 0.5);
		s += texture(TEXTURE, clamp(point + d * r, vec2(0.0), vec2(1.0)));
	}
	vec3 fill = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	float a = keep_alpha ? c.a : 1.0;
	vec3 o = mix(fill, rgb, blend);
	COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
}
