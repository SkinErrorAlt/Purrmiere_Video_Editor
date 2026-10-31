shader_type canvas_item;
render_mode blend_disabled;

uniform float bpm : hint_range(30.0, 300.0) = 120.0;
uniform float offset : hint_range(-10.0, 10.0) = 0.0;
uniform int every : hint_range(0, 3) = 0;
uniform float scale : hint_range(0.0, 50.0) = 6.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.2;
uniform float decay : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float clip_time;

vec2 mirror(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

void fragment() {
	float mul = every == 1 ? 0.5 : (every == 2 ? 0.25 : (every == 3 ? 2.0 : 1.0));
	float beats = (clip_time - offset) * max(bpm, 1.0) / 60.0 * mul;
	float env = 0.0;
	if (beats >= 0.0) {
		float ph = fract(beats);
		env = pow(1.0 - ph, 2.0 + decay * 10.0);
	}
	float s = 1.0 + scale * 0.01 * env;
	vec4 c = texture(TEXTURE, mirror((UV - centre) / s + centre));
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	rgb = rgb * (1.0 + brightness * env) + brightness * 0.25 * env;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
