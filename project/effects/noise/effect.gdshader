shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float time = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 0.15;
uniform float size : hint_range(0.5, 20.0) = 1.0;
uniform bool monochrome = true;
uniform bool animate = true;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 cell = floor(UV * tex_size / max(size, 0.5));
	float t = animate ? floor(time * 60.0) : 0.0;
	vec3 n;
	if (monochrome) {
		n = vec3(hash(vec3(cell, t)));
	} else {
		n = vec3(hash(vec3(cell, t)), hash(vec3(cell + 7.0, t)), hash(vec3(cell + 13.0, t)));
	}
	rgb += (n - 0.5) * amount;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
