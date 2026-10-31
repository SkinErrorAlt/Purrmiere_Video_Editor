shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float strip : hint_range(0.0, 0.3) = 0.03;
uniform float shift : hint_range(0.0, 300.0) = 80.0;
uniform float noise : hint_range(0.0, 1.0) = 0.7;
uniform bool at_top = false;
uniform float speed : hint_range(0.0, 60.0) = 24.0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float from_edge = at_top ? UV.y : 1.0 - UV.y;
	float inside = 1.0 - smoothstep(0.0, max(strip, 0.0001), from_edge);
	float row = floor(UV.y * size.y);
	float seed = floor(time * max(speed, 0.001));
	float wob = hash12(vec2(row, seed)) - 0.5;
	float dx = inside * (shift * max(px_scale, 0.0001) / size.x) * (0.4 + wob);
	vec2 uv = clamp(UV + vec2(dx, 0.0), vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, uv);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float n = hash12(UV * size * 0.9 + seed * 5.1);
	rgb = mix(rgb, vec3(n), inside * noise);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
