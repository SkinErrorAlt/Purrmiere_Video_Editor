shader_type canvas_item;
render_mode blend_disabled;

uniform float line_gap : hint_range(1.0, 32.0) = 3.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.05, 0.95) = 0.5;
uniform float roll : hint_range(-20.0, 20.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.15;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float gap = max(line_gap * max(px_scale, 0.0001), 1.0);
	float y = UV.y * tex_size.y + time * roll * gap;
	float f = fract(y / gap);
	float line = smoothstep(thickness, thickness + 0.25, f) * smoothstep(1.0, 1.0 - 0.25, f);
	rgb *= mix(1.0, 1.0 - darkness, 1.0 - line);
	rgb += rgb * glow * line;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
