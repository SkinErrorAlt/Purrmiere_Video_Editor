shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float radius : hint_range(1.0, 4.0) = 2.0;
uniform float reach : hint_range(2.0, 16.0) = 6.0;
uniform float edge : hint_range(0.05, 0.8) = 0.25;
uniform bool show = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float luma_at(sampler2D tex, vec2 uv) {
	return dot(straight(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	float y = dot(rgb, LUMA);
	float lo = y;
	float hi = y;
	float far_r = max(reach * ps, 1.0);
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926991;
		vec2 dir = vec2(cos(ang), sin(ang));
		float l1 = luma_at(TEXTURE, UV + dir * px * far_r);
		float l2 = luma_at(TEXTURE, UV + dir * px * far_r * 0.5);
		lo = min(lo, min(l1, l2));
		hi = max(hi, max(l1, l2));
	}
	float near_edge = smoothstep(edge * 0.6, edge, hi - lo);
	float tol = 0.01 + 0.08 * clamp(strength, 0.0, 1.0);
	int r = int(clamp(ceil(radius), 1.0, 4.0));
	float step_px = max(radius / float(r), 0.5) * ps;
	vec3 sum = rgb;
	float wsum = 1.0;
	for (int dy = -4; dy <= 4; dy++) {
		if (abs(dy) > r) {
			continue;
		}
		for (int dx = -4; dx <= 4; dx++) {
			if (abs(dx) > r || (dx == 0 && dy == 0)) {
				continue;
			}
			vec2 o = vec2(float(dx), float(dy));
			vec3 n = straight(texture(TEXTURE, clamp(UV + o * px * step_px, vec2(0.0), vec2(1.0))));
			float diff = abs(dot(n, LUMA) - y);
			float w = (1.0 - smoothstep(tol * 0.5, tol, diff)) * exp(-0.5 * dot(o, o) / max(float(r * r), 1.0));
			sum += n * w;
			wsum += w;
		}
	}
	vec3 smooth_rgb = sum / wsum;
	float amt = near_edge * clamp(strength * 1.4, 0.0, 1.0);
	vec3 outc = mix(rgb, smooth_rgb, amt);
	if (show) {
		outc = mix(vec3(y * 0.35), vec3(0.2, 0.9, 1.0), amt);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
