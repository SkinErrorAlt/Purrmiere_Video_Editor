shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float threshold : hint_range(0.02, 0.6) = 0.15;
uniform bool bright = true;
uniform bool dark = true;
uniform int size : hint_range(0, 1) = 0;
uniform bool show = false;

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	int ring = size == 1 ? 2 : 1;
	vec3 hi = vec3(0.0);
	vec3 lo = vec3(1.0);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			if (max(abs(i), abs(j)) != ring) {
				continue;
			}
			vec3 s = straight(texture(TEXTURE, clamp(UV + vec2(float(i), float(j)) * px, vec2(0.0), vec2(1.0))));
			hi = max(hi, s);
			lo = min(lo, s);
			sum += s;
			n += 1.0;
		}
	}
	vec3 typical = (sum - hi - lo) / max(n - 2.0, 1.0);
	vec3 hot = bright ? smoothstep(vec3(threshold), vec3(threshold * 1.3), rgb - hi) : vec3(0.0);
	vec3 cold = dark ? smoothstep(vec3(threshold), vec3(threshold * 1.3), lo - rgb) : vec3(0.0);
	vec3 w = max(hot, cold);
	vec3 outc = mix(rgb, typical, w);
	if (show) {
		float m = max(w.r, max(w.g, w.b));
		outc = mix(outc * 0.35, vec3(1.0, 0.1, 0.9), m);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
