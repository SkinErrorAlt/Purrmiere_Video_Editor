shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius : hint_range(0.0, 60.0) = 10.0;
uniform int iris_sides = 0;
uniform float iris_rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float highlight : hint_range(0.0, 4.0) = 1.5;
uniform bool edge = true;
uniform float squeeze : hint_range(0.4, 2.5) = 1.0;
uniform float cats_eye : hint_range(0.0, 1.0) = 0.0;
uniform float onion : hint_range(0.0, 1.0) = 0.0;
uniform float swirl : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec4 fetch(sampler2D tex, vec2 uv) {
	if (!edge && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		return vec4(0.0);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

float polygon_radius(float theta) {
	if (iris_sides < 3) {
		return 1.0;
	}
	float k = float(iris_sides);
	float seg = 6.28318530718 / k;
	float a = mod(theta - radians(iris_rotation), seg) - seg * 0.5;
	return cos(seg * 0.5) / max(cos(a), 0.0001);
}

vec2 swirl_uv(vec2 uv, vec2 o, float r, float aspect, vec2 px, float far) {
	vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
	float rad = length(d);
	if (rad < 0.0001) {
		return uv;
	}
	vec2 nr = d / rad;
	float st = 1.0 + clamp(swirl, 0.0, 1.0) * 1.6 * pow(clamp(far, 0.0, 1.0), 1.5);
	float arc = o.y * st * r * px.y;
	float ang = arc / max(rad, 0.06);
	float nl = max(rad + (o.x / st) * r * px.y, 0.0001);
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 rr = vec2(nr.x * ca - nr.y * sa, nr.x * sa + nr.y * ca) * nl;
	return 0.5 + rr / vec2(aspect, 1.0);
}

vec4 shaped_blur(sampler2D tex, vec2 uv, float r) {
	vec2 sq = vec2(1.0 / sqrt(squeeze), sqrt(squeeze));
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
	float far = length(d) / max(length(vec2(aspect, 1.0) * 0.5), 0.0001);
	vec2 nd = length(d) > 0.00001 ? normalize(d / sq) : vec2(1.0, 0.0);
	float shift = clamp(cats_eye, 0.0, 1.0) * 1.2 * pow(clamp(far, 0.0, 1.0), 1.5);
	float r_eff = r * max(sq.x, sq.y);
	float sw = clamp(swirl, 0.0, 1.0);
	float sw_mix = sw * smoothstep(0.0, 0.3, far);
	int n = int(clamp(0.6 * r_eff * r_eff * (1.0 + shift + sw * 1.5), 32.0, 256.0));
	vec2 px = 1.0 / tex_size;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 256; i++) {
		if (i >= n) {
			break;
		}
		float rr = sqrt((float(i) + 0.5) / float(n));
		float th = float(i) * 2.39996323;
		float pr = polygon_radius(th);
		if (rr > pr) {
			continue;
		}
		vec2 o = vec2(cos(th), sin(th)) * rr;
		if (length(o - nd * shift * 0.5) > 1.0 || length(o + nd * shift * 0.5) > 1.0) {
			continue;
		}
		vec2 os = o * sq;
		vec2 flat_uv = uv + os * r * px;
		vec2 at = sw_mix > 0.0 ? mix(flat_uv, swirl_uv(uv, os, r, aspect, px, far), sw_mix) : flat_uv;
		vec4 s = fetch(tex, at);
		float l = dot(s.rgb, LUMA);
		float q = rr / max(pr, 0.0001);
		float ring = 0.5 + 0.5 * cos(q * 15.7079633);
		float rim = smoothstep(0.55, 0.95, q);
		float shape = mix(1.0, 0.6 + 0.4 * ring + 0.5 * rim, clamp(onion, 0.0, 1.0));
		float w = 1.0 + pow(clamp(l, 0.0, 1.0), 4.0) * highlight * 8.0 * shape;
		sum += s * w;
		wsum += w;
	}
	if (wsum <= 0.0) {
		return texture(tex, uv);
	}
	return sum / wsum;
}

void fragment() {
	float r = radius * px_scale;
	if (r >= 0.5 && (squeeze != 1.0 || cats_eye > 0.0 || onion > 0.0 || swirl > 0.0)) {
		COLOR = shaped_blur(TEXTURE, UV, r);
	} else if (r < 0.5) {
		COLOR = texture(TEXTURE, UV);
	} else {
		int n = int(clamp(0.6 * r * r, 32.0, 256.0));
		vec2 px = 1.0 / tex_size;
		vec4 sum = vec4(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 256; i++) {
			if (i >= n) {
				break;
			}
			float rr = sqrt((float(i) + 0.5) / float(n));
			float th = float(i) * 2.39996323;
			float pr = polygon_radius(th);
			if (rr > pr) {
				continue;
			}
			vec2 off = vec2(cos(th), sin(th)) * rr * r * px;
			vec4 s = fetch(TEXTURE, UV + off);
			float l = dot(s.rgb, LUMA);
			float w = 1.0 + pow(clamp(l, 0.0, 1.0), 4.0) * highlight * 8.0;
			sum += s * w;
			wsum += w;
		}
		COLOR = sum / max(wsum, 0.0001);
	}
}
