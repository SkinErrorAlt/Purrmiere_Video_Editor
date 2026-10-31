shader_type canvas_item;
render_mode blend_disabled;

uniform int segments : hint_range(2, 32) = 6;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float spin : hint_range(-360.0, 360.0) = 0.0;
uniform float zoom : hint_range(0.1, 4.0) = 1.0;
uniform vec2 tex_size;

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float ang = atan(d.y, d.x) + radians(spin);
	float wedge = 6.28318530718 / float(max(segments, 2));
	ang = mod(ang, wedge);
	ang = min(ang, wedge - ang);
	vec2 src = centre + vec2(cos(ang), sin(ang)) * r / max(zoom, 0.0001) / aspect;
	src = clamp(src, vec2(0.0), vec2(1.0));
	COLOR = texture(TEXTURE, src);
}
