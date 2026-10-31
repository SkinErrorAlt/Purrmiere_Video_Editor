uniform sampler2D from_tex : filter_linear, repeat_disable;
uniform sampler2D to_tex : filter_linear, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 frame_px = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;
uniform float seed = 0.0;
uniform float duration = 1.0;
uniform float time = 0.0;

const float TR_PI = 3.14159265358979;

float tr_ratio() {
	return frame_px.x / max(frame_px.y, 1.0);
}

bool tr_inside(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

vec4 from_at(vec2 uv) {
	return tr_inside(uv) ? texture(from_tex, uv) : vec4(0.0);
}

vec4 to_at(vec2 uv) {
	return tr_inside(uv) ? texture(to_tex, uv) : vec4(0.0);
}

vec4 from_clamped(vec2 uv) {
	return texture(from_tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec4 to_clamped(vec2 uv) {
	return texture(to_tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec4 from_mirrored(vec2 uv) {
	vec2 m = 1.0 - abs(1.0 - mod(uv, 2.0));
	return texture(from_tex, m);
}

vec4 to_mirrored(vec2 uv) {
	vec2 m = 1.0 - abs(1.0 - mod(uv, 2.0));
	return texture(to_tex, m);
}

vec4 tr_over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

vec4 tr_shade(vec4 c, float light) {
	return vec4(c.rgb * light, c.a);
}

float tr_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031 + seed * 0.0173);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 tr_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973) + seed * 0.0173);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float tr_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = tr_hash(i);
	float b = tr_hash(i + vec2(1.0, 0.0));
	float c = tr_hash(i + vec2(0.0, 1.0));
	float d = tr_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float tr_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * tr_noise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

vec2 tr_rotate(vec2 p, float radians) {
	float c = cos(radians);
	float s = sin(radians);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float tr_ease(float t, int kind) {
	t = clamp(t, 0.0, 1.0);
	if (kind == 1) {
		return t * t;
	} else if (kind == 2) {
		return 1.0 - (1.0 - t) * (1.0 - t);
	} else if (kind == 3) {
		return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5;
	} else if (kind == 4) {
		return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5;
	} else if (kind == 5) {
		float c1 = 1.70158;
		float c3 = c1 + 1.0;
		return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
	} else if (kind == 6) {
		if (t >= 1.0) {
			return 1.0;
		}
		return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (2.0 * TR_PI / 3.0)) + 1.0;
	} else if (kind == 7) {
		float n1 = 7.5625;
		float d1 = 2.75;
		if (t < 1.0 / d1) {
			return n1 * t * t;
		} else if (t < 2.0 / d1) {
			t -= 1.5 / d1;
			return n1 * t * t + 0.75;
		} else if (t < 2.5 / d1) {
			t -= 2.25 / d1;
			return n1 * t * t + 0.9375;
		}
		t -= 2.625 / d1;
		return n1 * t * t + 0.984375;
	}
	return t;
}

vec2 tr_world(vec2 uv) {
	return vec2((uv.x - 0.5) * tr_ratio(), 0.5 - uv.y);
}

vec2 tr_frame_uv(vec2 world) {
	return vec2(world.x / tr_ratio() + 0.5, 0.5 - world.y);
}

mat3 tr_rotation(vec3 degrees) {
	vec3 r = radians(degrees);
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(r.x), sin(r.x)), vec3(0.0, -sin(r.x), cos(r.x)));
	mat3 ry = mat3(vec3(cos(r.y), 0.0, -sin(r.y)), vec3(0.0, 1.0, 0.0), vec3(sin(r.y), 0.0, cos(r.y)));
	mat3 rz = mat3(vec3(cos(r.z), sin(r.z), 0.0), vec3(-sin(r.z), cos(r.z), 0.0), vec3(0.0, 0.0, 1.0));
	return rz * ry * rx;
}

float tr_camera_distance(float fov_degrees) {
	return 0.5 / tan(radians(clamp(fov_degrees, 1.0, 170.0)) * 0.5);
}

vec4 tr_card(vec2 uv, vec3 rot_degrees, vec3 pivot, vec3 offset, vec2 card_size, float fov_degrees) {
	float d = tr_camera_distance(fov_degrees);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec2 s = tr_world(uv);
	vec3 dir = normalize(vec3(s, 0.0) - cam);
	mat3 r = tr_rotation(rot_degrees);
	mat3 ri = transpose(r);
	vec3 o = ri * (cam - offset - pivot) + pivot;
	vec3 dl = ri * dir;
	if (abs(dl.z) < 0.000001) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	float t = -o.z / dl.z;
	if (t <= 0.0) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	vec3 hit = o + dl * t;
	vec2 card_uv = vec2(hit.x / card_size.x + 0.5, 0.5 - hit.y / card_size.y);
	if (!tr_inside(card_uv)) {
		return vec4(card_uv, 0.0, -1.0);
	}
	float face = dl.z > 0.0 ? 1.0 : -1.0;
	return vec4(card_uv, face, t);
}

float tr_card_light(vec3 rot_degrees, vec3 light_dir) {
	mat3 r = tr_rotation(rot_degrees);
	vec3 n = r * vec3(0.0, 0.0, -1.0);
	return clamp(abs(dot(normalize(n), normalize(-light_dir))), 0.0, 1.0);
}

vec4 tr_card_sample(vec4 hit, bool use_from, bool mirror_back) {
	if (hit.w < 0.0) {
		return vec4(0.0);
	}
	vec2 cuv = hit.xy;
	if (hit.z < 0.0 && mirror_back) {
		cuv.x = 1.0 - cuv.x;
	}
	return use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
}

uniform sampler2D tr_from_pyr : filter_linear, repeat_disable;
uniform sampler2D tr_to_pyr : filter_linear, repeat_disable;
uniform vec2 tr_pyr_px = vec2(1.0, 1.0);
uniform int tr_pyr_levels = 0;

const float TR_PYR_GAP = 2.0;

vec2 tr_level_px(int trp_l) {
	return max(ceil(frame_px / exp2(float(trp_l))), vec2(1.0));
}

vec2 tr_level_origin(int trp_l) {
	if (trp_l <= 1) {
		return vec2(0.0);
	}
	vec2 trp_o = vec2(tr_level_px(1).x + TR_PYR_GAP, 0.0);
	for (int trp_k = 2; trp_k < 7; trp_k++) {
		if (trp_k >= trp_l) {
			break;
		}
		trp_o.y += tr_level_px(trp_k).y + TR_PYR_GAP;
	}
	return trp_o;
}

vec4 tr_pyr_tap(bool trp_from, vec2 trp_o, vec2 trp_s, vec2 trp_p) {
	vec2 trp_a = (trp_o + clamp(trp_p, vec2(0.5), trp_s - 0.5)) / max(tr_pyr_px, vec2(1.0));
	return trp_from ? texture(tr_from_pyr, trp_a) : texture(tr_to_pyr, trp_a);
}

vec4 tr_pyr_level(bool trp_from, vec2 trp_uv, int trp_l) {
	vec2 trp_s = tr_level_px(trp_l);
	vec2 trp_o = tr_level_origin(trp_l);
	vec2 trp_p = trp_uv * trp_s - 0.5;
	vec2 trp_i = floor(trp_p);
	vec2 trp_f = trp_p - trp_i;
	vec2 trp_f2 = trp_f * trp_f;
	vec2 trp_f3 = trp_f2 * trp_f;
	vec2 trp_w0 = (1.0 - 3.0 * trp_f + 3.0 * trp_f2 - trp_f3) / 6.0;
	vec2 trp_w1 = (4.0 - 6.0 * trp_f2 + 3.0 * trp_f3) / 6.0;
	vec2 trp_w2 = (1.0 + 3.0 * trp_f + 3.0 * trp_f2 - 3.0 * trp_f3) / 6.0;
	vec2 trp_w3 = trp_f3 / 6.0;
	vec2 trp_g0 = trp_w0 + trp_w1;
	vec2 trp_g1 = trp_w2 + trp_w3;
	vec2 trp_x0 = trp_i - 1.0 + trp_w1 / max(trp_g0, vec2(0.000001)) + 0.5;
	vec2 trp_x1 = trp_i + 1.0 + trp_w3 / max(trp_g1, vec2(0.000001)) + 0.5;
	vec4 trp_c00 = tr_pyr_tap(trp_from, trp_o, trp_s, trp_x0);
	vec4 trp_c10 = tr_pyr_tap(trp_from, trp_o, trp_s, vec2(trp_x1.x, trp_x0.y));
	vec4 trp_c01 = tr_pyr_tap(trp_from, trp_o, trp_s, vec2(trp_x0.x, trp_x1.y));
	vec4 trp_c11 = tr_pyr_tap(trp_from, trp_o, trp_s, trp_x1);
	return trp_g0.y * (trp_g0.x * trp_c00 + trp_g1.x * trp_c10) + trp_g1.y * (trp_g0.x * trp_c01 + trp_g1.x * trp_c11);
}

vec4 tr_lod(bool trp_from, vec2 trp_uv, float trp_lod) {
	if (!tr_inside(trp_uv)) {
		return vec4(0.0);
	}
	vec4 trp_base = trp_from ? texture(from_tex, trp_uv) : texture(to_tex, trp_uv);
	float trp_lv = clamp(trp_lod, 0.0, float(max(tr_pyr_levels, 0)));
	if (tr_pyr_levels <= 0 || trp_lv <= 0.0) {
		return trp_base;
	}
	int trp_l0 = int(floor(trp_lv));
	float trp_t = trp_lv - float(trp_l0);
	vec4 trp_a = trp_l0 == 0 ? trp_base : tr_pyr_level(trp_from, trp_uv, trp_l0);
	if (trp_t <= 0.0 || trp_l0 >= tr_pyr_levels) {
		return trp_a;
	}
	return mix(trp_a, tr_pyr_level(trp_from, trp_uv, trp_l0 + 1), trp_t);
}

float tr_blur_lod(float trp_r) {
	return trp_r <= 1.0 ? 0.0 : log2(trp_r);
}

vec4 from_lod(vec2 trp_uv, float trp_lod) {
	return tr_lod(true, trp_uv, trp_lod);
}

vec4 to_lod(vec2 trp_uv, float trp_lod) {
	return tr_lod(false, trp_uv, trp_lod);
}

vec4 from_blur(vec2 trp_uv, float trp_r) {
	return tr_lod(true, trp_uv, tr_blur_lod(trp_r));
}

vec4 to_blur(vec2 trp_uv, float trp_r) {
	return tr_lod(false, trp_uv, tr_blur_lod(trp_r));
}
