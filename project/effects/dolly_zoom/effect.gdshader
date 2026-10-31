shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform float amount : hint_range(-1.0, 1.0) = 0.5;
uniform float subject_size : hint_range(0.05, 1.0) = 0.25;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int timing : hint_range(0, 2) = 2;
uniform float seconds : hint_range(0.1, 60.0) = 3.0;
uniform int edges : hint_range(0, 2) = 0;

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
		return texture(tex, uv);
	}
	if (edges == 1) {
		return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	}
	vec2 m = mod(uv, 2.0);
	return texture(tex, clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0)));
}

float build() {
	if (timing == 0) {
		return 1.0;
	}
	float span = timing == 1 ? max(clip_duration, 0.001) : max(seconds, 0.1);
	float x = clamp(clip_time / span, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 asp = vec2(size.x / size.y, 1.0);
	float k = clamp(amount, -1.0, 1.0) * 0.9 * build();
	float big_r = clamp(subject_size, 0.05, 1.0);
	float ring = max(0.6, 2.0 * big_r);
	vec2 q = (UV - centre) * asp;
	float r = length(q);
	float g = smoothstep(big_r, big_r + ring, r);
	float f = k >= 0.0 ? 1.0 / (1.0 + k * g) : 1.0 - k * g;
	vec2 src = q * f / asp + centre;
	COLOR = fetch(TEXTURE, src);
}
