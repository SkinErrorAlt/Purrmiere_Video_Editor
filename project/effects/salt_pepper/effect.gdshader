shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float density : hint_range(0.0, 0.2) = 0.01;
uniform float balance : hint_range(0.0, 1.0) = 0.5;
uniform float speck : hint_range(1.0, 8.0) = 1.0;
uniform bool animate = true;
uniform vec2 tex_size;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 cell = floor(UV * tex_size / max(speck, 1.0));
	float seed = animate ? floor(time * 24.0) : 0.0;
	float r = hash12(cell + seed * 53.1);
	if (r < density) {
		float pick = hash12(cell + seed * 53.1 + 7.0);
		rgb = vec3(pick < balance ? 1.0 : 0.0);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
