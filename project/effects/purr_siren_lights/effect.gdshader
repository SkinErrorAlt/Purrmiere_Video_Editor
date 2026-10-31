shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour_a : source_color = vec4(1.0, 0.08, 0.12, 1.0);
uniform vec4 colour_b : source_color = vec4(0.1, 0.3, 1.0, 1.0);
uniform int mode : hint_range(0, 2) = 0;
uniform float rate : hint_range(0.1, 8.0) = 1.5;
uniform float strength : hint_range(0.0, 2.0) = 0.9;
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float clip_time;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float ph = fract(clip_time * rate);
	float strobe = step(0.0, sin(ph * 6.28318 * 4.0));
	vec3 L = vec3(0.0);
	if (mode == 0) {
		float left = smoothstep(0.75, 0.0, UV.x);
		float right = smoothstep(0.25, 1.0, UV.x);
		float fa = step(ph, 0.5) * step(0.0, sin(ph * 6.28318 * 4.0));
		float fb = step(0.5, ph) * step(0.0, sin(ph * 6.28318 * 4.0));
		L = colour_a.rgb * left * fa + colour_b.rgb * right * fb;
	} else if (mode == 1) {
		L = mix(colour_a.rgb, colour_b.rgb, step(0.5, ph)) * strobe;
	} else {
		float beam = 0.5 + 0.5 * cos((UV.x - 0.5) * 3.0 - ph * 6.28318 * 2.0);
		L = mix(colour_a.rgb, colour_b.rgb, step(0.5, fract(ph * 2.0 + 0.25))) * pow(beam, 3.0);
	}
	vec3 o = s * (1.0 - darken) + s * L * strength + L * strength * 0.12;
	COLOR = pm(o, c.a);
}
