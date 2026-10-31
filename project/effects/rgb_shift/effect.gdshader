shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform vec2 red = vec2(-3.0, 0.0);
uniform vec2 green = vec2(0.0, 0.0);
uniform vec2 blue = vec2(3.0, 0.0);
uniform float jitter : hint_range(0.0, 20.0) = 0.0;
uniform float speed : hint_range(0.0, 60.0) = 24.0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float seed = floor(time * max(speed, 0.001));
	float j = (hash12(vec2(floor(UV.y * size.y), seed)) - 0.5) * jitter;
	float s = max(px_scale, 0.0001);
	vec4 cr = texture(TEXTURE, clamp(UV + (red * s + vec2(j, 0.0)) / size, vec2(0.0), vec2(1.0)));
	vec4 cg = texture(TEXTURE, clamp(UV + green * s / size, vec2(0.0), vec2(1.0)));
	vec4 cb = texture(TEXTURE, clamp(UV + (blue * s - vec2(j, 0.0)) / size, vec2(0.0), vec2(1.0)));
	float a = max(cg.a, max(cr.a, cb.a));
	vec3 rgb = vec3(cr.a > 0.0001 ? cr.r / cr.a : 0.0, cg.a > 0.0001 ? cg.g / cg.a : 0.0, cb.a > 0.0001 ? cb.b / cb.a : 0.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
