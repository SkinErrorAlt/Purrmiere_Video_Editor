shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float position : hint_range(0.0, 1.0) = 0.5;
uniform float height : hint_range(0.0, 0.5) = 0.06;
uniform float offset : hint_range(0.0, 200.0) = 40.0;
uniform float noise : hint_range(0.0, 1.0) = 0.5;
uniform float drift : hint_range(-4.0, 4.0) = 0.25;
uniform float tear : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float centre = fract(position + time * drift);
	float d = abs(fract(UV.y - centre + 0.5) - 0.5);
	float half_h = max(height, 0.0001) * 0.5;
	float inside = 1.0 - smoothstep(half_h * (1.0 - tear), half_h, d);
	float row = floor(UV.y * size.y);
	float rough = (hash12(vec2(row, floor(time * 30.0))) - 0.5) * tear;
	float shift = (offset * max(px_scale, 0.0001) / size.x) * inside * (1.0 + rough);
	vec2 uv = clamp(UV + vec2(shift, 0.0), vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, uv);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float n = hash12(UV * size * 0.7 + floor(time * 30.0) * 13.0) - 0.5;
	rgb += n * noise * inside;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
