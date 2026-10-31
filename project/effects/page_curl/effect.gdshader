shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 150.0;
uniform float radius : hint_range(0.01, 0.5) = 0.12;
uniform int back : hint_range(0, 1) = 0;
uniform vec4 back_colour : source_color = vec4(0.93, 0.91, 0.87, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform float feather : hint_range(0.0, 0.05) = 0.001;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);

const float HALF_TURN = 3.14159265;
const vec2 SUN = vec2(-0.3713907, 0.9284767);
const vec2 GLINT = vec2(-0.1891, 0.9820);
float box_sd(vec2 q, float asp) {
	vec2 half_size = vec2(asp, 1.0) * 0.5;
	vec2 dq = abs(q - half_size) - half_size;
	return length(max(dq, vec2(0.0))) + min(max(dq.x, dq.y), 0.0);
}

float rect_cover(vec2 q, float asp, float aa) {
	return clamp(0.5 - box_sd(q, asp) / aa, 0.0, 1.0);
}

float soft_cover(vec2 q, float asp, float width) {
	return smoothstep(width, -width, box_sd(q, asp));
}

vec3 straight(vec4 s) {
	return s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
}

vec4 back_face(vec4 s, float shade, float glint) {
	vec3 pic = straight(s);
	float grey = dot(pic, vec3(0.2126, 0.7152, 0.0722));
	vec3 base = mix(pic, vec3(grey), 0.25) * 0.55 + vec3(0.08);
	float alpha = s.a;
	if (back == 1) {
		base = back_colour.rgb;
		alpha = s.a * back_colour.a;
	}
	vec3 col = clamp(base * shade + vec3(glint), 0.0, 1.0);
	return vec4(col * alpha, alpha);
}

vec4 front_face(vec4 s, float shade) {
	vec3 pic = straight(s);
	return vec4(clamp(pic * shade, 0.0, 1.0) * s.a, s.a);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float asp = size.x / size.y;
	float aa = max(feather, 1.0 / size.y);
	float rad_a = radians(angle);
	vec2 d = vec2(cos(rad_a), -sin(rad_a));
	if (invert) {
		d = -d;
	}
	float umin = min(0.0, d.x * asp) + min(0.0, d.y);
	float umax = max(0.0, d.x * asp) + max(0.0, d.y);
	float span = umax - umin;
	float r = max(radius, 0.001);
	float c = mix(0.0, span + r * 2.2 + aa * 4.0, clamp(progress, 0.0, 1.0));
	vec2 p = vec2(UV.x * asp, UV.y);
	float u = dot(p, d) - umin;
	vec2 to_uv = vec2(1.0 / asp, 1.0);
	vec4 top = vec4(0.0);
	vec4 below = vec4(0.0);
	bool flat_front = false;
	if (u >= c) {
		flat_front = true;
		below = texture(TEXTURE, UV);
		float us = 2.0 * c - HALF_TURN * r - u;
		vec2 src = p + (us - u) * d;
		float cov = rect_cover(src, asp, aa);
		if (cov > 0.0) {
			vec4 s = texture(TEXTURE, clamp(src * to_uv, vec2(0.0), vec2(1.0)));
			float glint = 0.35 * pow(GLINT.y, 200.0);
			top = back_face(s, 1.0, glint) * cov;
		}
	} else if (u >= c - r - aa) {
		float k = clamp((c - u) / r, 0.0, 1.0);
		float phi_hi = HALF_TURN - asin(k);
		float phi_lo = asin(k);
		float sil = clamp((u - (c - r)) / aa + 0.5, 0.0, 1.0);
		vec2 src_lo = p + (c - r * phi_lo - u) * d;
		vec2 src_hi = p + (c - r * phi_hi - u) * d;
		float cov_lo = rect_cover(src_lo, asp, aa) * sil;
		float cov_hi = rect_cover(src_hi, asp, aa) * sil;
		if (cov_lo > 0.0) {
			vec2 n_in = vec2(sin(phi_lo), cos(phi_lo));
			float lit = max(dot(n_in, SUN), 0.0) / SUN.y;
			float shade = 0.3 + 0.7 * lit;
			vec4 s = texture(TEXTURE, clamp(src_lo * to_uv, vec2(0.0), vec2(1.0)));
			below = front_face(s, shade) * cov_lo;
		}
		if (cov_hi > 0.0) {
			vec2 n_out = vec2(-sin(phi_hi), -cos(phi_hi));
			float lit = max(dot(n_out, SUN), 0.0) / SUN.y;
			float shade = 0.3 + 0.7 * lit;
			float glint = 0.35 * pow(max(dot(n_out, GLINT), 0.0), 200.0);
			vec4 s = texture(TEXTURE, clamp(src_hi * to_uv, vec2(0.0), vec2(1.0)));
			top = back_face(s, shade, glint) * cov_hi;
		}
	}
	float page_sh = 0.0;
	float ground_sh = 0.0;
	if (shadow > 0.0) {
		float w = r * 0.8 + aa;
		vec2 at_rim = p + (c - HALF_TURN * r * 0.5 - u) * d;
		float rim = soft_cover(at_rim, asp, w * 0.5);
		if (u >= c) {
			float us = 2.0 * c - HALF_TURN * r - u;
			float gap = max(box_sd(p + (us - u) * d, asp), 0.0) / w;
			float from_flap = exp(-gap * gap * 2.0);
			float gap2 = (u - c) / (r * 0.6 + aa);
			float from_roll = exp(-gap2 * gap2) * rim * 0.7;
			page_sh = max(from_flap, from_roll);
		} else {
			float gap = max((c - r) - u, 0.0) / w;
			ground_sh = exp(-gap * gap * 1.5) * rim;
		}
		page_sh *= shadow;
		ground_sh *= shadow;
	}
	if (flat_front) {
		below.rgb *= 1.0 - page_sh * 0.7;
	}
	vec4 ground = vec4(0.0, 0.0, 0.0, clamp(ground_sh * 0.8, 0.0, 1.0));
	vec4 under = below + ground * (1.0 - below.a);
	vec4 result = top + under * (1.0 - top.a);
	COLOR = vec4(clamp(result.rgb, vec3(0.0), vec3(clamp(result.a, 0.0, 1.0))), clamp(result.a, 0.0, 1.0));
}
