const float FLOW_RANGE = 256.0;

vec4 flow_encode(vec2 v) {
	vec2 q = clamp(round((v + FLOW_RANGE) / (2.0 * FLOW_RANGE) * 65535.0), vec2(0.0), vec2(65535.0));
	vec2 hi = floor(q / 256.0);
	vec2 lo = q - hi * 256.0;
	return vec4(hi.x / 255.0, lo.x / 255.0, hi.y / 255.0, lo.y / 255.0);
}

vec2 flow_decode(vec4 c) {
	vec2 q = vec2(round(c.r * 255.0) * 256.0 + round(c.g * 255.0), round(c.b * 255.0) * 256.0 + round(c.a * 255.0));
	return q / 65535.0 * 2.0 * FLOW_RANGE - FLOW_RANGE;
}

vec2 flow_fetch(sampler2D t, ivec2 p) {
	ivec2 hi = textureSize(t, 0) - ivec2(1);
	return flow_decode(texelFetch(t, clamp(p, ivec2(0), hi), 0));
}

vec2 flow_at(sampler2D t, vec2 uv) {
	vec2 sz = vec2(textureSize(t, 0));
	vec2 p = uv * sz - 0.5;
	vec2 f = fract(p);
	ivec2 i = ivec2(floor(p));
	vec2 a = flow_fetch(t, i);
	vec2 b = flow_fetch(t, i + ivec2(1, 0));
	vec2 c = flow_fetch(t, i + ivec2(0, 1));
	vec2 d = flow_fetch(t, i + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float flow_cost(sampler2D luma_tex, vec2 size, vec2 c, vec2 d, float lambda, int patch) {
	float s = 0.0;
	for (int oy = -patch; oy <= patch; oy++) {
		for (int ox = -patch; ox <= patch; ox++) {
			vec2 o = vec2(float(ox), float(oy));
			s += abs(texture(luma_tex, (c + o) / size).r - texture(luma_tex, (c + d + o) / size).g);
		}
	}
	return s + lambda * (abs(d.x) + abs(d.y));
}
