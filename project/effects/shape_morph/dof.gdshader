shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(960.0, 540.0);
uniform float px_scale = 1.0;
uniform sampler2D colour_tex : filter_linear, repeat_disable;
uniform float focus : hint_range(0.05, 40.0) = 1.3737;
uniform float lens_blur : hint_range(0.0, 60.0) = 0.0;

const float GOLDEN = 2.39996323;

vec3 depth_at(sampler2D dt, vec2 uv) {
	ivec2 sz = textureSize(dt, 0);
	ivec2 ip = clamp(ivec2(floor(uv * vec2(sz))), ivec2(0), sz - ivec2(1));
	vec4 e = texelFetch(dt, ip, 0);
	float d = (e.r * 255.0 + e.g) / 255.0 * 32.0;
	return vec3(d, e.b, 0.0);
}

float coc_of(vec3 dc) {
	float far_coc = 2.5 * lens_blur;
	if (dc.y < 0.02 || dc.x < 0.0001) {
		return far_coc;
	}
	return min(2.0 * lens_blur * abs(1.0 - focus / dc.x), far_coc);
}

void fragment() {
	vec2 to_uv = vec2(px_scale) / tex_size;
	vec3 dc = depth_at(TEXTURE, UV);
	float coc_c = dc.y > 0.02 ? coc_of(dc) : 0.0;
	float reach = coc_c;
	float rmax = 2.5 * lens_blur;
	for (int i = 0; i < 12; i++) {
		float r = rmax * (0.35 + 0.65 * float(i % 2));
		float a = float(i) * 0.5235988;
		vec2 o = vec2(cos(a), sin(a)) * r;
		vec3 dn = depth_at(TEXTURE, UV + o * to_uv);
		if (dn.y > 0.02) {
			float cn = coc_of(dn);
			if (cn >= r * 0.8) {
				reach = max(reach, min(cn, r * 1.25));
			}
		}
	}
	vec4 acc = texture(colour_tex, UV);
	float wsum = 1.0;
	if (reach > 0.6) {
		for (int i = 1; i < 48; i++) {
			float fr = sqrt(float(i) / 48.0);
			float r = fr * reach;
			float a = float(i) * GOLDEN;
			vec2 o = vec2(cos(a), sin(a)) * r * to_uv;
			vec3 dt = depth_at(TEXTURE, UV + o);
			float ct = coc_of(dt);
			float w = clamp(ct - r + 1.0, 0.0, 1.0);
			acc += texture(colour_tex, UV + o) * w;
			wsum += w;
		}
	}
	COLOR = acc / wsum;
}
