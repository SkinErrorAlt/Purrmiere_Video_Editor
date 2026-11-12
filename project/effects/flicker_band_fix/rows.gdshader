shader_type canvas_item;
render_mode blend_disabled;

uniform int direction = 0;

const int STRIPS = 16;
const int PER_STRIP = 24;
const float LOG_LO = -14.0;
const float LOG_SPAN = 14.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

void fragment() {
	vec2 ax = direction == 0 ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
	vec2 across = vec2(1.0) - ax;
	int lane = int(floor(dot(FRAGCOORD.xy, across)));
	if (lane > STRIPS + 1) {
		COLOR = vec4(0.0);
	} else {
		float along = dot(UV, ax);
		int s0 = lane < STRIPS ? lane : 0;
		int s1 = lane < STRIPS ? lane + 1 : STRIPS;
		vec3 sum = vec3(0.0);
		float wsum = 0.0;
		float n = 0.0;
		for (int s = s0; s < s1; s++) {
			for (int i = 0; i < PER_STRIP; i++) {
				float t = (float(s) + (float(i) + 0.5) / float(PER_STRIP)) / float(STRIPS);
				vec4 c = texture(TEXTURE, ax * along + across * t);
				vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
				float lo = min(rgb.r, min(rgb.g, rgb.b));
				float hi = max(rgb.r, max(rgb.g, rgb.b));
				float w = smoothstep(0.002, 0.006, lo) * (1.0 - smoothstep(0.975, 0.995, hi)) * step(0.5, c.a);
				sum += to_linear(rgb) * w;
				wsum += w;
				n += 1.0;
			}
		}
		vec3 m = sum / max(wsum, 0.0001);
		float cover = smoothstep(0.03, 0.15, wsum / max(n, 1.0));
		if (lane < STRIPS) {
			float l = (log2(max(dot(m, LUMA), 0.00007)) - LOG_LO) / LOG_SPAN;
			COLOR = vec4(split16(l), cover, 1.0);
		} else {
			vec3 l = (log2(max(m, vec3(0.00007))) - LOG_LO) / LOG_SPAN;
			vec2 r = split16(l.r);
			vec2 g = split16(l.g);
			vec2 b = split16(l.b);
			COLOR = lane == STRIPS ? vec4(r.x, g.x, b.x, cover) : vec4(r.y, g.y, b.y, cover);
		}
	}
}
