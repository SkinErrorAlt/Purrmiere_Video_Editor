shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int shape : hint_range(0, 1) = 0;
uniform float radius : hint_range(0.5, 10.0) = 1.5;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform float strength : hint_range(0.0, 1.0) = 0.7;
uniform int iterations : hint_range(1, 8) = 4;
uniform float halos : hint_range(0.0, 1.0) = 0.15;

vec3 est_at(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

vec3 obs_at(vec2 uv) {
	return texture(effect_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	float r = clamp(radius, 0.5, 10.0);
	vec4 est = texture(TEXTURE, UV);
	vec4 obs = texture(effect_tex, UV);
	vec3 blurred = vec3(0.0);
	if (shape == 1) {
		float a = radians(angle);
		vec2 dir = vec2(sin(a), -cos(a));
		vec3 s = vec3(0.0);
		for (int i = 0; i < 17; i++) {
			float t = (float(i) / 16.0 - 0.5) * 2.0 * r;
			s += est_at(TEXTURE, UV + dir * px * t);
		}
		blurred = s / 17.0;
	} else {
		vec3 s = est.rgb;
		float n = 1.0;
		for (int i = 0; i < 24; i++) {
			float fi = float(i) + 0.5;
			float rr = sqrt(fi / 24.0) * r;
			float ang = fi * 2.3999632;
			s += est_at(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px * rr);
			n += 1.0;
		}
		blurred = s / n;
	}
	vec3 next = est.rgb + clamp(strength, 0.0, 1.0) * (obs.rgb - blurred);
	vec3 lo = obs.rgb;
	vec3 hi = obs.rgb;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec2 d = vec2(cos(ang), sin(ang));
		vec3 n1 = obs_at(UV + d * px);
		vec3 n2 = obs_at(UV + d * px * max(r, 1.0));
		lo = min(lo, min(n1, n2));
		hi = max(hi, max(n1, n2));
	}
	float hl = clamp(halos, 0.0, 1.0);
	vec3 room = (hi - lo) * hl * 0.5 + vec3(hl * 0.02);
	next = clamp(next, lo - room, hi + room);
	next = clamp(next, vec3(0.0), vec3(obs.a));
	COLOR = vec4(next, obs.a);
}
