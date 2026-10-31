shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform float direction : hint_range(-180.0, 180.0) = 135.0;
uniform float reach : hint_range(0.0, 100.0) = 8.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float rad = radians(direction);
	vec2 step_uv = vec2(cos(rad), sin(rad)) * max(reach * max(px_scale, 0.0001), 0.0) / max(tex_size, vec2(1.0));
	float away = 0.0;
	for (int i = 1; i <= 6; i++) {
		float t = float(i) / 6.0;
		away += texture(TEXTURE, UV - step_uv * t).a;
	}
	away /= 6.0;
	float hole = clamp((a - away) * mix(4.0, 1.0, softness), 0.0, 1.0);
	rgb = mix(rgb, colour.rgb, hole * colour.a);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
