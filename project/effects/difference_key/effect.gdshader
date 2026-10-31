shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D clean_plate : filter_linear, repeat_disable, hint_default_transparent;
uniform float tolerance : hint_range(0.0, 1.0) = 0.08;
uniform float softness : hint_range(0.0, 1.0) = 0.08;
uniform int matching : hint_range(0, 2) = 0;
uniform float pre_blur : hint_range(0.0, 20.0) = 2.0;
uniform bool show_matte = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));
const vec2 CROSS[4] = vec2[4](vec2(0.3827, 0.9239), vec2(-0.9239, 0.3827), vec2(-0.3827, -0.9239), vec2(0.9239, -0.3827));

vec4 soft_plate(sampler2D tex, vec2 uv, vec2 reach) {
	vec4 sum = texture(tex, uv) * 4.0;
	for (int i = 0; i < 4; i++) {
		sum += texture(tex, clamp(uv + CROSS[i] * reach * 0.5, vec2(0.0), vec2(1.0))) * 2.0;
	}
	for (int i = 0; i < 8; i++) {
		sum += texture(tex, clamp(uv + RING[i] * reach, vec2(0.0), vec2(1.0)));
	}
	return sum / 20.0;
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec4 plate_here = texture(clean_plate, UV);
	if (plate_here.a <= 0.0001) {
		COLOR = c;
	} else {
		vec2 reach = vec2(pre_blur * px_scale) / max(tex_size, vec2(1.0));
		vec4 pic_soft = c;
		vec4 plate_soft = plate_here;
		if (pre_blur * px_scale > 0.25) {
			pic_soft = c * 4.0;
			for (int i = 0; i < 4; i++) {
				pic_soft += texture(TEXTURE, clamp(UV + CROSS[i] * reach * 0.5, vec2(0.0), vec2(1.0))) * 2.0;
			}
			for (int i = 0; i < 8; i++) {
				pic_soft += texture(TEXTURE, clamp(UV + RING[i] * reach, vec2(0.0), vec2(1.0)));
			}
			pic_soft /= 20.0;
			plate_soft = soft_plate(clean_plate, UV, reach);
		}
		vec3 p = straight(pic_soft);
		vec3 q = straight(plate_soft);
		float d = 0.0;
		if (matching == 1) {
			d = abs(luma(p) - luma(q));
		} else if (matching == 2) {
			vec3 cp = p / max(p.r + p.g + p.b, 0.0001);
			vec3 cq = q / max(q.r + q.g + q.b, 0.0001);
			float lit = smoothstep(0.02, 0.12, max(luma(p), luma(q)));
			d = length(cp - cq) * 1.5 * lit;
		} else {
			d = length(p - q) * 0.57735;
		}
		float matte = smoothstep(tolerance, tolerance + max(softness, 0.0001), d);
		float oa = clamp(a * matte, 0.0, 1.0);
		vec3 rgb = straight(c);
		if (show_matte) {
			COLOR = vec4(vec3(oa), 1.0);
		} else {
			COLOR = vec4(rgb * oa, oa);
		}
	}
}
