shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float spin : hint_range(-360.0, 360.0) = 0.0;
uniform float scale_r : hint_range(0.1, 4.0) = 1.0;

void fragment() {
	vec2 src;
	if (mode == 0) {
		vec2 d = UV - centre;
		float r = length(d) * 2.0 / max(scale_r, 0.0001);
		float ang = atan(d.y, d.x) + radians(spin);
		src = vec2(fract(ang / 6.28318530718 + 0.5), clamp(r, 0.0, 1.0));
	} else {
		float ang = (UV.x - 0.5) * 6.28318530718 + radians(spin);
		float r = UV.y * 0.5 * max(scale_r, 0.0001);
		src = centre + vec2(cos(ang), sin(ang)) * r;
	}
	COLOR = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
}
