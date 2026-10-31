shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float scratches : hint_range(0.0, 1.0) = 0.4;
uniform float dust : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.0, 60.0) = 12.0;
uniform vec2 tex_size;
uniform float time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float seed = floor(time * max(speed, 0.001));
	float col = floor(UV.x * tex_size.x / 2.0);
	float pick = hash12(vec2(col, seed));
	if (pick > 1.0 - scratches * 0.02) {
		float bright = hash12(vec2(col, seed + 3.0));
		rgb = mix(rgb, vec3(bright > 0.5 ? 1.0 : 0.05), 0.85);
	}
	vec2 dcell = floor(UV * tex_size / 3.0);
	float d = hash12(dcell + seed * 29.0);
	if (d > 1.0 - dust * 0.01) {
		rgb = mix(rgb, vec3(hash12(dcell + seed * 29.0 + 1.0)), 0.9);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
