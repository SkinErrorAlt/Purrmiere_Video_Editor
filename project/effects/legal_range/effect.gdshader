shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 2) = 0;
uniform float max_ire : hint_range(90.0, 110.0) = 100.0;
uniform float min_ire : hint_range(-10.0, 10.0) = 0.0;
uniform float chroma_limit : hint_range(0.1, 1.0) = 0.85;
uniform bool show_illegal = false;
uniform vec4 illegal_colour : source_color = vec4(1.0, 0.0, 0.8, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float CHROMA_FULL = 0.6;

vec2 chroma_of(vec3 rgb, float y) {
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

vec3 from_ycc(float y, vec2 cc) {
	return vec3(y + 1.5748 * cc.y, y - 0.187324 * cc.x - 0.468124 * cc.y, y + 1.8556 * cc.x);
}

vec3 pull_into(vec3 rgb, float y, float lo, float hi) {
	float peak = max(rgb.r, max(rgb.g, rgb.b));
	if (peak > hi) {
		rgb = mix(rgb, vec3(y), clamp((peak - hi) / max(peak - y, 0.0001), 0.0, 1.0));
	}
	float floor_v = min(rgb.r, min(rgb.g, rgb.b));
	if (floor_v < lo) {
		rgb = mix(rgb, vec3(y), clamp((lo - floor_v) / max(y - floor_v, 0.0001), 0.0, 1.0));
	}
	return rgb;
}

float soft_limit(float y, float lo, float hi) {
	float kw = 0.08;
	if (hi < 1.0 && y > hi - kw) {
		y = hi - kw + kw * (1.0 - exp(-(y - (hi - kw)) / kw));
	}
	if (lo > 0.0 && y < lo + kw) {
		y = lo + kw - kw * (1.0 - exp(-((lo + kw) - y) / kw));
	}
	return y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float lo = min_ire / 100.0;
	float hi = max(max_ire / 100.0, lo + 0.05);
	float limit = max(chroma_limit, 0.01) * CHROMA_FULL;
	float y = dot(rgb, LUMA);
	vec2 cc = chroma_of(rgb, y);
	float cn = length(cc);
	float eps = 0.0005;
	bool bad_luma = y > hi + eps || y < lo - eps;
	bool bad_rgb = max(rgb.r, max(rgb.g, rgb.b)) > hi + eps || min(rgb.r, min(rgb.g, rgb.b)) < lo - eps;
	bool bad_chroma = cn > limit + eps;
	vec3 result = rgb;
	if (show_illegal) {
		if (bad_luma || bad_rgb || bad_chroma) {
			result = illegal_colour.rgb;
		}
	} else if (mode == 0) {
		vec2 cc2 = cn > limit ? cc * (limit / max(cn, 0.0001)) : cc;
		result = clamp(from_ycc(clamp(y, lo, hi), cc2), vec3(lo), vec3(hi));
	} else if (mode == 1) {
		float y2 = clamp(soft_limit(y, lo, hi), lo, hi);
		vec2 cc2 = cn > limit ? cc * (limit / max(cn, 0.0001)) : cc;
		result = pull_into(from_ycc(y2, cc2), y2, lo, hi);
		result = clamp(result, vec3(lo), vec3(hi));
	} else {
		float y2 = clamp(y, lo, hi);
		vec2 cc2 = cn > limit ? cc * (limit / max(cn, 0.0001)) : cc;
		result = pull_into(from_ycc(y2, cc2), y2, lo, hi);
		result = clamp(result, vec3(lo), vec3(hi));
	}
	COLOR = vec4(clamp(result, 0.0, 1.0) * a, a);
}
