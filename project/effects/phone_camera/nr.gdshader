shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float smear : hint_range(0.0, 1.0) = 0.55;
uniform float spread = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c0 = texture(TEXTURE, UV);
	if (smear <= 0.0001) {
		COLOR = c0;
	} else {
		vec2 px = 1.0 / tex_size;
		float step_px = spread * max(px_scale, 0.25);
		float y0 = dot(c0.rgb, LUMA);
		float sr = 0.012 + 0.11 * smear;
		float inv_r = 1.0 / (2.0 * sr * sr);
		float yc = 0.0;
		float wy = 0.0;
		vec3 cc = vec3(0.0);
		float wc = 0.0;
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				vec2 o = vec2(float(i), float(j));
				vec4 s = texture(TEXTURE, UV + o * step_px * px);
				float y = dot(s.rgb, LUMA);
				float d2 = dot(o, o);
				float ws = exp(-d2 * 0.22);
				float dy = y - y0;
				float w = ws * exp(-dy * dy * inv_r);
				yc += y * w;
				wy += w;
				float wcol = ws * exp(-dy * dy * inv_r * 0.15);
				cc += (s.rgb - vec3(y)) * wcol;
				wc += wcol;
			}
		}
		float ys = yc / max(wy, 0.00001);
		vec3 chroma = cc / max(wc, 0.00001);
		vec3 own = c0.rgb - vec3(y0);
		float ynew = mix(y0, ys, clamp(smear * 1.4, 0.0, 1.0));
		vec3 cnew = mix(own, chroma, clamp(smear * 1.8, 0.0, 1.0));
		COLOR = vec4(clamp(vec3(ynew) + cnew, vec3(0.0), vec3(c0.a)), c0.a);
	}
}
