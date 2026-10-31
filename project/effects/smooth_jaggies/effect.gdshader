shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float reach : hint_range(1.0, 12.0) = 3.0;
uniform float pixel_size : hint_range(1.0, 8.0) = 1.0;
uniform float edge : hint_range(0.02, 0.5) = 0.06;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float lum(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return c.a > 0.0001 ? dot(clamp(c.rgb / c.a, 0.0, 1.0), LUMA) * c.a : 0.0;
}

void fragment() {
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	float cell = clamp(pixel_size, 1.0, 8.0);
	float q = cell * max(1.0, reach / 3.0);
	float grid[25];
	for (int j = 0; j < 5; j++) {
		for (int i = 0; i < 5; i++) {
			grid[j * 5 + i] = lum(TEXTURE, UV + px * q * vec2(float(i - 2), float(j - 2)));
		}
	}
	float sxx = 0.0;
	float sxy = 0.0;
	float syy = 0.0;
	float wsum = 0.0;
	for (int j = 1; j <= 3; j++) {
		for (int i = 1; i <= 3; i++) {
			float gx = grid[j * 5 + i + 1] - grid[j * 5 + i - 1];
			float gy = grid[(j + 1) * 5 + i] - grid[(j - 1) * 5 + i];
			float w = (i == 2 && j == 2) ? 2.0 : 1.0;
			sxx += gx * gx * w;
			sxy += gx * gy * w;
			syy += gy * gy * w;
			wsum += w;
		}
	}
	sxx /= wsum;
	sxy /= wsum;
	syy /= wsum;
	float tr = sxx + syy;
	float diff = sqrt(max((sxx - syy) * (sxx - syy) + 4.0 * sxy * sxy, 0.0));
	float l1 = 0.5 * (tr + diff);
	float l2 = 0.5 * (tr - diff);
	float coherence = tr > 1e-6 ? (l1 - l2) / (l1 + l2 + 1e-6) : 0.0;
	float grad_angle = 0.5 * atan(2.0 * sxy, sxx - syy);
	vec2 tangent = vec2(-sin(grad_angle), cos(grad_angle));
	float mag = sqrt(max(l1, 0.0)) * 0.5;
	float edge_w = smoothstep(edge * 0.5, edge, mag) * smoothstep(0.3, 0.7, coherence);
	vec4 centre = texture(TEXTURE, UV);
	vec4 sum = centre;
	float tw = 1.0;
	float len = clamp(reach, 1.0, 12.0) * cell;
	for (int k = 1; k <= 8; k++) {
		float t = float(k) / 8.0 * len;
		float w = exp(-2.0 * (t / len) * (t / len));
		sum += texture(TEXTURE, clamp(UV + tangent * px * t, vec2(0.0), vec2(1.0))) * w;
		sum += texture(TEXTURE, clamp(UV - tangent * px * t, vec2(0.0), vec2(1.0))) * w;
		tw += 2.0 * w;
	}
	vec4 along = sum / tw;
	COLOR = mix(centre, along, edge_w * clamp(strength, 0.0, 1.0));
}
