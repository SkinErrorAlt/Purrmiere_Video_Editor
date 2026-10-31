shader_type canvas_item;
render_mode blend_disabled;

uniform float amplitude : hint_range(0.0, 400.0) = 20.0;
uniform float wavelength : hint_range(1.0, 800.0) = 120.0;
uniform float phase : hint_range(-360.0, 360.0) = 0.0;
uniform float speed : hint_range(-10.0, 10.0) = 0.0;
uniform bool vertical = false;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float wl = max(wavelength * max(px_scale, 0.0001), 1.0);
	float along = vertical ? UV.x * size.x : UV.y * size.y;
	float w = sin(along / wl * 6.28318530718 + radians(phase) + time * speed * 6.28318530718);
	vec2 off = vertical ? vec2(0.0, w) : vec2(w, 0.0);
	off *= amplitude * max(px_scale, 0.0001) / size;
	COLOR = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
}
