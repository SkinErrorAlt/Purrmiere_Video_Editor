shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float zoom : hint_range(0.1, 8.0) = 2.0;
uniform float radius : hint_range(0.01, 1.0) = 0.2;
uniform float edge : hint_range(0.0, 0.5) = 0.02;
uniform vec2 tex_size;

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float inside = 1.0 - smoothstep(max(radius - edge, 0.0), radius, r);
	vec2 zoomed = centre + d / max(zoom, 0.0001) / aspect;
	vec2 src = mix(UV, zoomed, inside);
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
