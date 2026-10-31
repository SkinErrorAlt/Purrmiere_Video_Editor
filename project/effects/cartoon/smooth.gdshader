shader_type canvas_item;
render_mode blend_disabled;

uniform float smoothing : hint_range(0.0, 12.0) = 3.0;
uniform float colour_tolerance : hint_range(0.02, 0.5) = 0.12;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec4 c0 = texture(TEXTURE, UV);
	float step_px = smoothing * px_scale * 0.5;
	if (step_px < 0.25) {
		COLOR = c0;
	} else {
		vec2 dims = max(tex_size, vec2(1.0));
		vec3 ref = c0.a > 0.0001 ? c0.rgb / c0.a : vec3(0.0);
		float tol = max(colour_tolerance, 0.02);
		float inv_range = 1.0 / (2.0 * tol * tol);
		vec4 sum = vec4(0.0);
		float wsum = 0.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				vec2 o = vec2(float(x), float(y));
				vec4 s = texture(TEXTURE, clamp(UV + o * step_px / dims, vec2(0.0), vec2(1.0)));
				vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
				vec3 dc = sr - ref;
				float da = s.a - c0.a;
				float w = exp(-dot(o, o) / 4.5) * exp(-(dot(dc, dc) + da * da) * inv_range);
				sum += s * w;
				wsum += w;
			}
		}
		COLOR = sum / max(wsum, 0.0001);
	}
}
