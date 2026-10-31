shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float block : hint_range(1.0, 32.0) = 2.0;
uniform float bands : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.0, 60.0) = 24.0;
uniform vec2 tex_size;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 cell = floor(UV * tex_size / max(block, 1.0));
	float seed = floor(time * max(speed, 0.001));
	float s = hash12(cell + seed * 91.3);
	float roll = sin((UV.y + time * 0.35) * 40.0) * 0.5 + 0.5;
	float mask = amount * mix(1.0, roll, bands);
	rgb = mix(rgb, vec3(s), clamp(mask, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
