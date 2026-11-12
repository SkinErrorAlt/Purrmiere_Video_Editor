shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(960.0, 540.0);
uniform float px_scale = 1.0;
uniform sampler2D colour_tex : filter_linear, repeat_disable;
uniform sampler2D depth_tex : filter_nearest, repeat_disable;
uniform float focus : hint_range(0.05, 40.0) = 1.3737;
uniform float lens_blur : hint_range(0.0, 60.0) = 0.0;

vec2 depth_at(sampler2D dt, vec2 uv) {
	ivec2 sz = textureSize(dt, 0);
	ivec2 ip = clamp(ivec2(floor(uv * vec2(sz))), ivec2(0), sz - ivec2(1));
	vec4 e = texelFetch(dt, ip, 0);
	return vec2((e.r * 255.0 + e.g) / 255.0 * 32.0, e.b);
}

float coc_of(vec2 dc) {
	if (dc.y < 0.02 || dc.x < 0.0001) {
		return 0.0;
	}
	return min(2.0 * lens_blur * abs(1.0 - focus / dc.x), 2.5 * lens_blur);
}

void fragment() {
	vec2 to_uv = vec2(px_scale) / tex_size;
	vec4 sharp = texture(colour_tex, UV);
	vec4 soft = texture(TEXTURE, UV);
	float reach = coc_of(depth_at(depth_tex, UV));
	float rmax = 2.5 * lens_blur;
	for (int i = 0; i < 8; i++) {
		float r = rmax * (0.3 + 0.7 * float(i % 2));
		float a = float(i) * 0.785398 + 0.2;
		vec2 dn = depth_at(depth_tex, UV + vec2(cos(a), sin(a)) * r * to_uv);
		float cn = coc_of(dn);
		if (cn >= r * 0.8) {
			reach = max(reach, min(cn, r * 1.25) * 0.8);
		}
	}
	float w = smoothstep(0.8, 2.4, reach * px_scale * 2.0);
	COLOR = mix(sharp, soft, w);
}
