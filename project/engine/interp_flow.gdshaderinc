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

float flow_cost(sampler2D luma_tex, vec2 size, vec2 c, vec2 d, float w, float lambda, int patch) {
	vec2 pa = c - w * d;
	vec2 pb = c + (1.0 - w) * d;
	float s = 0.0;
	for (int oy = -patch; oy <= patch; oy++) {
		for (int ox = -patch; ox <= patch; ox++) {
			vec2 o = vec2(float(ox), float(oy));
			s += abs(texture(luma_tex, (pa + o) / size).r - texture(luma_tex, (pb + o) / size).g);
		}
	}
	return s + lambda * (abs(d.x) + abs(d.y));
}
