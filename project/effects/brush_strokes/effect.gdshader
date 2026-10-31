shader_type canvas_item;
render_mode blend_disabled;

uniform float angle : hint_range(-180.0, 180.0) = 135.0;
uniform float stroke_length : hint_range(1.0, 60.0) = 10.0;
uniform float randomness : hint_range(0.0, 1.0) = 0.4;
uniform float bristles : hint_range(0.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;

float h(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float ps = max(px_scale, 0.0001);
	vec2 px = vec2(ps) / max(tex_size, vec2(1.0));
	vec2 sp = UV * tex_size / ps;
	vec2 cell = floor(sp / max(stroke_length * 0.6, 0.5));
	float a = radians(angle + (h(vec3(cell, float(seed))) - 0.5) * randomness * 90.0);
	vec2 dir = vec2(cos(a), -sin(a));
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 9; i++) {
		sum += texture(TEXTURE, UV + dir * (float(i) / 8.0 - 0.5) * stroke_length * px);
	}
	sum /= 9.0;
	float line = floor(dot(sp, vec2(-dir.y, dir.x)) / 1.5);
	float shade = 1.0 + (h(vec3(line, cell.x + cell.y * 7.0, float(seed))) - 0.5) * bristles * 0.35;
	vec3 rgb = sum.a > 0.0001 ? sum.rgb / sum.a : vec3(0.0);
	COLOR = vec4(clamp(rgb * shade, 0.0, 1.0) * sum.a, sum.a);
}
