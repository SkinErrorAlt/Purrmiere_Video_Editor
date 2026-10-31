shader_type canvas_item;
render_mode blend_disabled;

uniform int look : hint_range(0, 11) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(-2.0, 2.0) = 0.0;
uniform float contrast : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float keep_skin : hint_range(0.0, 1.0) = 0.3;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void look_params(int id, out vec3 wb, out vec3 lift, out vec3 gam, out vec3 gain, out vec3 sh, out vec3 hi, out vec4 shape, out int mixer) {
	mixer = 0;
	if (id == 1) {
		wb = vec3(0.96, 1.0, 1.04);
		lift = vec3(-0.005, 0.01, 0.015);
		gam = vec3(1.0, 1.02, 1.0);
		gain = vec3(0.98, 1.0, 1.0);
		sh = vec3(-0.01, 0.015, 0.01);
		hi = vec3(0.0, 0.01, 0.015);
		shape = vec4(0.9, 0.3, 0.02, 0.97);
	} else if (id == 2) {
		wb = vec3(1.02, 1.0, 0.98);
		lift = vec3(0.02, 0.02, 0.03);
		gam = vec3(1.05);
		gain = vec3(0.97, 0.97, 0.96);
		sh = vec3(0.0, 0.01, 0.02);
		hi = vec3(0.02, 0.01, -0.01);
		shape = vec4(0.78, -0.15, 0.09, 0.93);
	} else if (id == 3) {
		wb = vec3(1.12, 1.0, 0.8);
		lift = vec3(0.01, -0.005, 0.01);
		gam = vec3(1.05, 1.0, 0.95);
		gain = vec3(1.04, 1.0, 0.9);
		sh = vec3(0.01, -0.01, 0.02);
		hi = vec3(0.05, 0.025, -0.03);
		shape = vec4(1.15, 0.25, 0.01, 1.0);
	} else if (id == 4) {
		wb = vec3(0.88, 0.98, 1.15);
		lift = vec3(0.0, 0.01, 0.03);
		gam = vec3(1.05, 1.05, 1.08);
		gain = vec3(1.02, 1.04, 1.06);
		sh = vec3(-0.02, 0.0, 0.035);
		hi = vec3(-0.01, 0.0, 0.02);
		shape = vec4(0.65, 0.2, 0.02, 1.0);
	} else if (id == 5) {
		wb = vec3(0.95, 0.92, 1.1);
		lift = vec3(0.0, 0.0, 0.03);
		gam = vec3(1.0, 0.95, 1.05);
		gain = vec3(1.05, 0.98, 1.05);
		sh = vec3(0.0, 0.02, 0.05);
		hi = vec3(0.04, -0.015, 0.04);
		shape = vec4(1.3, 0.5, 0.0, 1.0);
	} else if (id == 6) {
		wb = vec3(0.9, 1.1, 0.88);
		lift = vec3(-0.01, 0.015, -0.01);
		gam = vec3(0.95, 1.05, 0.95);
		gain = vec3(0.95, 1.03, 0.92);
		sh = vec3(-0.01, 0.02, -0.005);
		hi = vec3(0.0, 0.02, -0.01);
		shape = vec4(0.75, 0.35, 0.01, 0.98);
		mixer = 2;
	} else if (id == 7) {
		wb = vec3(1.08, 1.03, 0.84);
		lift = vec3(0.02, 0.015, 0.0);
		gam = vec3(1.05, 1.03, 0.95);
		gain = vec3(1.0, 0.98, 0.88);
		sh = vec3(0.02, 0.005, -0.01);
		hi = vec3(0.03, 0.03, -0.03);
		shape = vec4(0.85, -0.05, 0.06, 0.94);
	} else if (id == 8) {
		wb = vec3(1.03, 1.0, 0.97);
		lift = vec3(0.0, 0.0, 0.01);
		gam = vec3(1.0);
		gain = vec3(1.02, 1.0, 0.98);
		sh = vec3(-0.01, 0.01, 0.015);
		hi = vec3(0.02, 0.01, -0.01);
		shape = vec4(1.2, 0.3, 0.02, 0.98);
		mixer = 1;
	} else if (id == 9) {
		wb = vec3(0.95, 1.04, 0.92);
		lift = vec3(-0.01, 0.005, -0.005);
		gam = vec3(0.88, 0.9, 0.88);
		gain = vec3(0.96, 1.0, 0.92);
		sh = vec3(-0.01, 0.02, 0.0);
		hi = vec3(0.0, 0.015, -0.02);
		shape = vec4(0.5, 0.45, 0.0, 0.95);
	} else if (id == 10) {
		wb = vec3(1.0);
		lift = vec3(0.0, 0.0, 0.005);
		gam = vec3(1.0);
		gain = vec3(1.0);
		sh = vec3(-0.005, 0.0, 0.012);
		hi = vec3(0.01, 0.005, -0.005);
		shape = vec4(1.0, 0.4, 0.01, 1.0);
		mixer = 3;
	} else if (id == 11) {
		wb = vec3(1.04, 1.0, 0.96);
		lift = vec3(0.0);
		gam = vec3(1.1);
		gain = vec3(1.02, 1.02, 1.0);
		sh = vec3(0.0, 0.0, 0.01);
		hi = vec3(0.02, 0.01, -0.01);
		shape = vec4(1.3, 0.15, 0.01, 1.0);
	} else {
		wb = vec3(1.05, 1.0, 0.93);
		lift = vec3(-0.01, 0.0, 0.02);
		gam = vec3(1.0);
		gain = vec3(1.0, 0.99, 0.95);
		sh = vec3(-0.015, 0.005, 0.02);
		hi = vec3(0.03, 0.012, -0.02);
		shape = vec4(0.92, 0.45, 0.015, 0.98);
	}
}

vec3 s_curve(vec3 c, float k) {
	vec3 x = clamp(c, 0.0, 1.0);
	return c + clamp(k, -1.0, 1.0) * (x * x * (3.0 - 2.0 * x) - x);
}

vec3 set_sat(vec3 c, float s) {
	float l = dot(c, LUMA);
	return vec3(l) + (c - vec3(l)) * s;
}

float hue_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		h /= 6.0;
	}
	return h;
}

float skin_weight(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float sat = mx > 0.0001 ? (mx - min(c.r, min(c.g, c.b))) / mx : 0.0;
	float l = dot(c, LUMA);
	float dh = abs(fract(hue_of(c) - 0.07 + 0.5) - 0.5);
	float w = 1.0 - smoothstep(0.04, 0.09, dh);
	w *= smoothstep(0.08, 0.2, sat) * (1.0 - smoothstep(0.65, 0.85, sat));
	return w * smoothstep(0.08, 0.2, l);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 orig = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 base = orig * exp2(clamp(exposure, -2.0, 2.0));
	vec3 wb;
	vec3 lift;
	vec3 gam;
	vec3 gain;
	vec3 sh;
	vec3 hi;
	vec4 shape;
	int mixer;
	look_params(clamp(look, 0, 11), wb, lift, gam, gain, sh, hi, shape, mixer);
	vec3 c = base;
	if (mixer == 1) {
		float cyan = (c.g + c.b) * 0.5;
		c = vec3(c.r, mix(c.g, cyan, 0.8), mix(c.b, cyan, 0.85));
	} else if (mixer == 2) {
		c = vec3(dot(c, vec3(0.7, 0.3, 0.0)), dot(c, vec3(0.1, 0.9, 0.0)), dot(c, vec3(0.0, 0.3, 0.7)));
	} else if (mixer == 3) {
		c = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	}
	c *= wb / max(dot(wb, LUMA), 0.05);
	c = gain * (c + lift * (vec3(1.0) - clamp(c, 0.0, 1.0)));
	c = pow(max(c, vec3(0.0)), vec3(1.0) / max(gam, vec3(0.05)));
	c = s_curve(c, shape.y);
	c = set_sat(c, shape.x);
	float l = clamp(dot(c, LUMA), 0.0, 1.0);
	c += sh * (1.0 - smoothstep(0.0, 0.6, l)) + hi * smoothstep(0.4, 1.0, l);
	c = vec3(shape.z) + c * (shape.w - shape.z);
	float w = clamp(warmth, -1.0, 1.0);
	vec3 warm = vec3(1.0 + 0.1 * w, 1.0, 1.0 - 0.12 * w);
	c *= warm / max(dot(warm, LUMA), 0.05);
	c = s_curve(c, contrast);
	c = set_sat(c, clamp(saturation, 0.0, 2.0));
	float f = clamp(fade, 0.0, 1.0);
	c = vec3(0.15 * f) + c * (1.0 - 0.22 * f);
	if (mixer != 3) {
		float keep = clamp(keep_skin, 0.0, 1.0) * skin_weight(orig) * 0.7;
		vec3 natural = set_sat(base, clamp(saturation, 0.0, 2.0));
		c = mix(c, natural * (dot(c, LUMA) / max(dot(natural, LUMA), 0.001)), keep);
	}
	c = mix(orig, clamp(c, 0.0, 1.0), clamp(strength, 0.0, 1.0));
	COLOR = vec4(clamp(c, 0.0, 1.0) * a, a);
}
