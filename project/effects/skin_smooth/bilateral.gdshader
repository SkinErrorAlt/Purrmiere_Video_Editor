shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 axis = vec2(1.0, 0.0);
uniform float radius : hint_range(1.0, 30.0) = 8.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb0 = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float r = max(radius * px_scale, 0.5);
	int n = int(min(ceil(r), 12.0));
	float stride = r / float(max(n, 1));
	float sigma = max(r * 0.5, 0.25);
	vec2 dir = axis / max(tex_size, vec2(1.0));
	vec3 sum = rgb0 * a;
	float wsum = a;
	for (int k = 1; k <= 12; k++) {
		if (k > n) {
			break;
		}
		float d = float(k) * stride;
		float ws = exp(-0.5 * d * d / (sigma * sigma));
		vec4 p = texture(TEXTURE, clamp(UV + dir * d, vec2(0.0), vec2(1.0)));
		vec4 m = texture(TEXTURE, clamp(UV - dir * d, vec2(0.0), vec2(1.0)));
		vec3 prgb = p.a > 0.0001 ? p.rgb / p.a : vec3(0.0);
		vec3 mrgb = m.a > 0.0001 ? m.rgb / m.a : vec3(0.0);
		vec3 dp = prgb - rgb0;
		vec3 dm = mrgb - rgb0;
		float wp = ws * exp(-dot(dp, dp) * 60.0) * p.a;
		float wm = ws * exp(-dot(dm, dm) * 60.0) * m.a;
		sum += prgb * wp + mrgb * wm;
		wsum += wp + wm;
	}
	vec3 outc = wsum > 0.0001 ? sum / wsum : rgb0;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
