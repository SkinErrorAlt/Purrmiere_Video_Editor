shader_type canvas_item;
render_mode blend_disabled;

uniform int copies : hint_range(1, 8) = 3;
uniform float spacing : hint_range(0.0, 200.0) = 24.0;
uniform float decay : hint_range(0.05, 1.0) = 0.45;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	int n = clamp(copies, 1, 8);
	float w = decay;
	for (int i = 1; i <= n; i++) {
		vec2 uv = clamp(UV - dir * (spacing * max(px_scale, 0.0001) * float(i)) / size, vec2(0.0), vec2(1.0));
		vec4 s = texture(TEXTURE, uv);
		vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		rgb += sr * tint.rgb * w * tint.a;
		w *= decay;
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
