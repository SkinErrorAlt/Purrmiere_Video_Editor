shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float amplitude : hint_range(0.0, 200.0) = 12.0;
uniform float wavelength : hint_range(1.0, 400.0) = 60.0;
uniform float speed : hint_range(-10.0, 10.0) = 1.0;
uniform float falloff : hint_range(0.0, 4.0) = 1.0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 d = (UV - centre) * size;
	float r = length(d);
	float wl = max(wavelength * max(px_scale, 0.0001), 1.0);
	float fade = 1.0 / (1.0 + pow(r / max(size.x, 1.0) * 2.0, max(falloff, 0.0)) * max(falloff, 0.0));
	float wave = sin(r / wl * 6.28318530718 - time * speed * 6.28318530718);
	vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
	vec2 off = dir * wave * amplitude * max(px_scale, 0.0001) * fade / size;
	COLOR = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
}
