shader_type canvas_item;
render_mode blend_disabled;

uniform float depth : hint_range(0.0, 60.0) = 8.0;
uniform int depth_from : hint_range(0, 1) = 0;
uniform int colour_mode : hint_range(0, 3) = 2;
uniform bool swap = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec3 lum_w = vec3(0.299, 0.587, 0.114);
	float shift = depth * px_scale;
	if (depth_from == 1) {
		vec4 c0 = texture(TEXTURE, UV);
		vec3 r0 = c0.a > 0.0001 ? c0.rgb / c0.a : vec3(0.0);
		shift *= (0.5 - dot(r0, lum_w)) * 2.0;
	}
	vec2 off = vec2(shift * 0.5 / dims.x, 0.0);
	if (swap) {
		off = -off;
	}
	vec4 lp = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
	vec4 rp = texture(TEXTURE, clamp(UV - off, vec2(0.0), vec2(1.0)));
	float al = lp.a;
	float ar = rp.a;
	vec3 cl = al > 0.0001 ? lp.rgb / al : vec3(0.0);
	vec3 cr = ar > 0.0001 ? rp.rgb / ar : vec3(0.0);
	vec3 outp;
	if (colour_mode == 0) {
		outp = vec3(dot(cl, lum_w) * al, 0.0, dot(cr, lum_w) * ar);
	} else if (colour_mode == 1) {
		float gr = dot(cr, lum_w) * ar;
		outp = vec3(dot(cl, lum_w) * al, gr, gr);
	} else if (colour_mode == 2) {
		outp = vec3(dot(cl, lum_w) * al, cr.g * ar, cr.b * ar);
	} else {
		vec3 ll = srgb_to_linear(cl) * al;
		vec3 rl = srgb_to_linear(cr) * ar;
		outp = vec3(
			dot(ll, vec3(0.4561, 0.500484, 0.176381)) + dot(rl, vec3(-0.0434706, -0.0879388, -0.00155529)),
			dot(ll, vec3(-0.0400822, -0.0378246, -0.0157589)) + dot(rl, vec3(0.378476, 0.73364, -0.0184503)),
			dot(ll, vec3(-0.0152161, -0.0205971, -0.00546856)) + dot(rl, vec3(-0.0721527, -0.112961, 1.2264)));
	}
	float a = max(al, ar);
	vec3 rgb = a > 0.0001 ? outp / a : vec3(0.0);
	if (colour_mode == 3) {
		rgb = linear_to_srgb(rgb);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
