shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float choke : hint_range(-40.0, 40.0) = 1.0;
uniform float softness : hint_range(0.0, 50.0) = 1.0;

void fragment() {
	float reach = (max(-choke, 0.0) + softness * 1.5 + 3.0) * px_scale;
	float stride = max(1.0, reach / 24.0);
	int n = int(min(ceil(reach / stride), 24.0));
	float px = 1.0 / max(tex_size.x, 1.0);
	float near_r = max(reach * 0.35, 1.0);
	vec3 csum = vec3(0.0);
	float wsum = 0.0;
	float fsum = 0.0;
	for (int k = 0; k <= 48; k++) {
		if (k > 2 * n) {
			break;
		}
		float off = float(k - n) * stride;
		vec4 s = texture(effect_tex, clamp(UV + vec2(off * px, 0.0), vec2(0.0), vec2(1.0)));
		float q = off / near_r;
		float f = 1.0 / (1.0 + q * q);
		float a2 = s.a * s.a;
		float w = a2 * a2 * s.a * f;
		csum += s.rgb * w;
		wsum += s.a * w;
		fsum += f;
	}
	vec3 col = wsum > 0.00001 ? clamp(csum / wsum, 0.0, 1.0) : vec3(0.0);
	float conf = sqrt(clamp(wsum / max(fsum, 0.00001), 0.0, 1.0));
	COLOR = vec4(col, conf);
}
