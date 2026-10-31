shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float direction : hint_range(-180.0, 180.0) = -45.0;
uniform float strength : hint_range(0.0, 8.0) = 1.5;
uniform float reach : hint_range(0.5, 32.0) = 3.0;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float rad = radians(direction);
	vec2 step_uv = vec2(cos(rad), sin(rad)) * max(reach * max(px_scale, 0.0001), 0.5) / max(tex_size, vec2(1.0));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec4 s = texture(TEXTURE, UV - step_uv);
	float here = dot(rgb, w);
	float back = dot(s.a > 0.0001 ? s.rgb / s.a : vec3(0.0), w);
	float rim = clamp((here - back) * strength, 0.0, 1.0);
	rgb += colour.rgb * rim * colour.a;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
