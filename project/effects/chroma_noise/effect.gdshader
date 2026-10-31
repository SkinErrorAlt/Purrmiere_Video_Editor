shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform float grain_size : hint_range(0.5, 16.0) = 3.0;
uniform bool animate = true;
uniform vec2 tex_size;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 cell = floor(UV * tex_size / max(grain_size, 0.5));
	float seed = animate ? floor(time * 24.0) : 0.0;
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 chroma = rgb - vec3(luma);
	vec3 n = vec3(hash12(cell + seed * 17.0), hash12(cell + seed * 17.0 + 5.0), hash12(cell + seed * 17.0 + 9.0)) - 0.5;
	chroma += n * strength;
	rgb = vec3(luma) + chroma;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
