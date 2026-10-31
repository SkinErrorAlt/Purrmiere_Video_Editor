shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float density : hint_range(0.0, 1.0) = 0.25;
uniform float length : hint_range(1.0, 200.0) = 40.0;
uniform float thickness : hint_range(1.0, 16.0) = 2.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.9;
uniform float speed : hint_range(0.0, 60.0) = 12.0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float seed = floor(time * max(speed, 0.001));
	float band = floor(UV.y * size.y / max(thickness * max(px_scale, 0.0001), 1.0));
	float seg = floor(UV.x * size.x / max(length * max(px_scale, 0.0001), 1.0));
	float hit = hash12(vec2(seg, band) + seed * 41.0);
	if (hit > 1.0 - density * 0.06) {
		rgb = mix(rgb, vec3(brightness), 0.95);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
