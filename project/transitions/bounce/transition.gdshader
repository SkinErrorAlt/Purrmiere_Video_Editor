shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int edge = 0;
uniform int bounces = 3;
uniform float bounciness : hint_range(0.05, 0.8) = 0.3;
uniform float squash : hint_range(0.0, 0.4) = 0.12;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform float shadow_size : hint_range(0.0, 0.5) = 0.15;
uniform vec4 shadow_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float CONTACT = 0.12;

vec2 drop_at(float p, out float press) {
	int n = clamp(bounces, 0, 8);
	float r = clamp(bounciness, 0.01, 0.95);
	float total = 1.0 + float(n + 1) * CONTACT;
	float h = 1.0;
	for (int k = 1; k <= 8; k++) {
		if (k > n) {
			break;
		}
		h *= r;
		total += 2.0 * sqrt(h);
	}
	float t = clamp(p, 0.0, 1.0) * total;
	press = 0.0;
	if (t < 1.0) {
		return vec2(1.0 - t * t, 0.0);
	}
	t -= 1.0;
	float speed = 1.0;
	h = 1.0;
	for (int k = 0; k <= 8; k++) {
		if (t < CONTACT || k >= n) {
			press = squash * speed * sin(TR_PI * clamp(t / CONTACT, 0.0, 1.0));
			return vec2(0.0, press);
		}
		t -= CONTACT;
		h *= r;
		float half_time = sqrt(h);
		if (t < 2.0 * half_time) {
			float x = (t - half_time) / half_time;
			return vec2(h * (1.0 - x * x), 0.0);
		}
		t -= 2.0 * half_time;
		speed = sqrt(h);
	}
	return vec2(0.0);
}

vec2 to_fall(vec2 uv) {
	if (edge == 1) {
		return vec2(uv.y, uv.x);
	} else if (edge == 2) {
		return vec2(uv.x, uv.y);
	} else if (edge == 3) {
		return vec2(1.0 - uv.x, uv.y);
	}
	return vec2(1.0 - uv.y, uv.x);
}

vec2 from_fall(vec2 f) {
	if (edge == 1) {
		return vec2(f.y, f.x);
	} else if (edge == 2) {
		return vec2(f.x, f.y);
	} else if (edge == 3) {
		return vec2(1.0 - f.x, f.y);
	}
	return vec2(f.y, 1.0 - f.x);
}

vec4 transition(vec2 uv) {
	float press;
	vec2 d = drop_at(progress, press);
	float off = d.x;
	vec2 f = to_fall(uv);
	if (f.x >= off && f.x <= off + 1.0) {
		float h = f.x - off;
		float low = (1.0 - h) * (1.0 - h);
		vec2 local = vec2(h + 2.0 * press * h * (1.0 - h), 0.5 + (f.y - 0.5) / (1.0 + 1.2 * press * low));
		vec2 tuv = from_fall(local);
		if (tr_inside(tuv)) {
			return texture(to_tex, tuv);
		}
	}
	vec4 c = texture(from_tex, uv);
	if (f.x >= off) {
		return c;
	}
	float unit = (edge >= 2) ? tr_ratio() : 1.0;
	float lift = off * unit;
	float above = f.x * unit;
	float near = clamp(1.0 - off, 0.0, 1.0);
	float soft = max(shadow_size, 0.0001) * (0.4 + 1.2 * lift);
	float s = shadow * shadow_colour.a * near * near * (1.0 - smoothstep(0.0, soft, above));
	vec4 sc = vec4(shadow_colour.rgb * c.a, c.a);
	return mix(c, sc, clamp(s, 0.0, 1.0));
}

void fragment() {
	COLOR = transition(UV);
}
