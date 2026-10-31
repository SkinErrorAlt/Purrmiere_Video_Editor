shader_type canvas_item;
render_mode blend_disabled;

uniform float zoom : hint_range(0.1, 5.0) = 0.6;
uniform float spin : hint_range(-180.0, 180.0) = 0.0;
uniform bool tunnel = false;
uniform vec2 tex_size;

void fragment() {
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = (UV - 0.5) * 2.0 * vec2(aspect, 1.0);
	float r = length(p) / max(zoom, 0.001);
	float lat = -1.5707963 + 2.0 * atan(r);
	if (tunnel) { lat = -lat; }
	float lon = atan(p.x, -p.y) + radians(spin);
	vec2 uv = vec2(fract(lon / 6.2831853 + 0.5), clamp(0.5 - lat / 3.14159265, 0.0, 1.0));
	COLOR = texture(TEXTURE, uv);
}
