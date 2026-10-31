shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform float px_scale = 1.0;
uniform float luma_strength : hint_range(0.0, 1.0) = 0.5;
uniform float chroma_strength : hint_range(0.0, 1.0) = 0.6;
uniform int search : hint_range(1, 5) = 3;
uniform float detail : hint_range(0.0, 1.0) = 0.15;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 ycc_at(ivec2 p, ivec2 size) {
	vec4 s = texelFetch(effect_tex, clamp(p, ivec2(0), size - 1), 0);
	vec3 rgb = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
	float y = dot(rgb, LUMA);
	return vec3(y, (rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

vec3 to_rgb(vec3 ycc) {
	float r = ycc.x + 1.5748 * ycc.z;
	float b = ycc.x + 1.8556 * ycc.y;
	float g = (ycc.x - 0.2126 * r - 0.0722 * b) / 0.7152;
	return vec3(r, g, b);
}

void fragment() {
	ivec2 size = textureSize(effect_tex, 0);
	ivec2 p = clamp(ivec2(floor(UV * vec2(size))), ivec2(0), size - 1);
	vec4 c = texelFetch(effect_tex, p, 0);
	float a = c.a;
	vec3 centre = ycc_at(p, size);
	vec3 pc0 = centre;
	vec3 pc1 = ycc_at(p + ivec2(1, 0), size);
	vec3 pc2 = ycc_at(p + ivec2(-1, 0), size);
	vec3 pc3 = ycc_at(p + ivec2(0, 1), size);
	vec3 pc4 = ycc_at(p + ivec2(0, -1), size);
	float hy = max(luma_strength * 0.1, 0.0005);
	float hc = max(chroma_strength * 0.16, 0.0005);
	int r = clamp(int(round(float(search) * clamp(px_scale, 0.34, 1.0))), 1, 5);
	float ysum = 0.0;
	float ywsum = 0.0;
	vec2 csum = vec2(0.0);
	float cwsum = 0.0;
	for (int j = -5; j <= 5; j++) {
		if (j < -r || j > r) {
			continue;
		}
		for (int i = -5; i <= 5; i++) {
			if (i < -r || i > r) {
				continue;
			}
			ivec2 q = p + ivec2(i, j);
			vec3 q0 = ycc_at(q, size);
			vec3 q1 = ycc_at(q + ivec2(1, 0), size);
			vec3 q2 = ycc_at(q + ivec2(-1, 0), size);
			vec3 q3 = ycc_at(q + ivec2(0, 1), size);
			vec3 q4 = ycc_at(q + ivec2(0, -1), size);
			vec3 d0 = pc0 - q0;
			vec3 d1 = pc1 - q1;
			vec3 d2 = pc2 - q2;
			vec3 d3 = pc3 - q3;
			vec3 d4 = pc4 - q4;
			float dy = (d0.x * d0.x * 2.0 + d1.x * d1.x + d2.x * d2.x + d3.x * d3.x + d4.x * d4.x) / 6.0;
			float dc = (dot(d0.yz, d0.yz) * 2.0 + dot(d1.yz, d1.yz) + dot(d2.yz, d2.yz) + dot(d3.yz, d3.yz) + dot(d4.yz, d4.yz)) / 6.0;
			float wy = exp(-dy / (hy * hy));
			float wc = exp(-(dy + dc) / (hc * hc));
			ysum += q0.x * wy;
			ywsum += wy;
			csum += q0.yz * wc;
			cwsum += wc;
		}
	}
	float y = ysum / max(ywsum, 0.000001);
	vec2 cc = csum / max(cwsum, 0.000001);
	y = mix(y, centre.x, detail);
	vec3 outc = clamp(to_rgb(vec3(y, cc)), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
