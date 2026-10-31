shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float size : hint_range(1.0, 60.0) = 2.0;
uniform int kind : hint_range(0, 2) = 0;
uniform bool animate = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

float h(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * tex_size / max(size * max(px_scale, 0.0001), 0.0001);
	float f = (animate ? floor(time * 24.0) : 0.0) + float(seed) * 17.0;
	float n;
	if (kind == 2) {
		vec2 i = floor(p);
		vec2 u = smoothstep(0.0, 1.0, fract(p));
		n = mix(mix(h(vec3(i, f)), h(vec3(i + vec2(1.0, 0.0), f)), u.x), mix(h(vec3(i + vec2(0.0, 1.0), f)), h(vec3(i + vec2(1.0), f)), u.x), u.y);
	} else {
		n = h(vec3(floor(p), f));
		if (kind == 1) { n *= n; }
	}
	COLOR = c * clamp(1.0 - amount * n, 0.0, 1.0);
}
