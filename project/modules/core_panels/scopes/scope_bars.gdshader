shader_type canvas_item;

// Draws a histogram from a one pixel high strip of counts (red, green and blue added up per bin).
uniform sampler2D counts : filter_nearest;
uniform float bins = 256.0;
uniform float norm = 1.0;
uniform int rows = 64;
uniform bool luma_only = false;

void fragment() {
	float x = (floor(UV.x * bins) + 0.5) / bins;
	vec3 c = vec3(0.0);
	for (int i = 0; i < rows; i++) {
		c += texture(counts, vec2(x, (float(i) + 0.5) / float(rows))).rgb;
	}
	c *= norm;
	vec3 h = clamp(log(1.0 + c * 1.5) / log(1.0 + 1.5 * 12.0), 0.0, 1.0);
	float y = 1.0 - UV.y;
	vec3 on = step(vec3(y), h);
	vec3 col = luma_only ? vec3(0.85) * on.r : vec3(1.0, 0.3, 0.25) * on.r + vec3(0.3, 1.0, 0.35) * on.g + vec3(0.3, 0.5, 1.0) * on.b;
	float a = clamp(max(on.r, max(on.g, on.b)) * 0.75, 0.0, 1.0);
	COLOR = vec4(min(col, vec3(1.0)), a);
}
