shader_type canvas_item;
render_mode blend_disabled;

uniform float period : hint_range(0.02, 10.0) = 0.5;
uniform float duration : hint_range(0.0, 1.0) = 0.2;
uniform int mode : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float random : hint_range(0.0, 1.0) = 0.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float fade : hint_range(0.0, 1.0) = 0.3;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float p = max(period, 0.02);
	float t = max(clip_time, 0.0) / p;
	float k = floor(t);
	float f = t - k;
	float d = clamp(duration, 0.0, 1.0);
	float env = 0.0;
	if (d > 0.0) {
		float fw = clamp(fade, 0.0, 1.0) * d * 0.5;
		if (fw > 0.0001) {
			env = smoothstep(0.0, fw, f) * (1.0 - smoothstep(d - fw, d, f));
		} else {
			env = f < d ? 1.0 : 0.0;
		}
	}
	float skip = hash12(vec2(k, 5.0) + seed_offset(seed));
	if (skip < random) {
		env = 0.0;
	}
	if (mode == 1) {
		rgb = mix(rgb, 1.0 - rgb, env);
	} else if (mode == 2) {
		a = a * (1.0 - env);
	} else if (mode == 3) {
		rgb = rgb * (1.0 - env);
	} else {
		rgb = mix(rgb, colour.rgb, env * colour.a);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
