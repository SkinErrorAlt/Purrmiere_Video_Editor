shader_type canvas_item;
render_mode blend_disabled;

uniform int input_from : hint_range(0, 5) = 0;
uniform int palette : hint_range(0, 4) = 0;
uniform float cycles : hint_range(0.1, 10.0) = 1.0;
uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(-5.0, 5.0) = 0.0;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform bool keep_lightness = false;
uniform vec4 colour_1 : source_color = vec4(0.1, 0.1, 0.5, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.9, 0.2, 0.4, 1.0);
uniform vec4 colour_3 : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float clip_time;

float hue_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	if (d < 0.00001) {
		return 0.0;
	}
	float h;
	if (mx == c.r) {
		h = mod((c.g - c.b) / d, 6.0);
	} else if (mx == c.g) {
		h = (c.b - c.r) / d + 2.0;
	} else {
		h = (c.r - c.g) / d + 4.0;
	}
	return h / 6.0;
}

vec3 cycle3(vec3 c0, vec3 c1, vec3 c2, float x) {
	float f = fract(x) * 3.0;
	float i = floor(f);
	float t = f - i;
	if (i < 0.5) {
		return mix(c0, c1, t);
	} else if (i < 1.5) {
		return mix(c1, c2, t);
	}
	return mix(c2, c0, t);
}

vec3 palette_at(float x) {
	float s = 0.5 - 0.5 * cos(6.2831853 * x);
	if (palette == 1) {
		return clamp(vec3(s * 3.0, s * 3.0 - 1.0, s * 3.0 - 2.0), 0.0, 1.0);
	} else if (palette == 2) {
		vec3 low = mix(vec3(0.02, 0.05, 0.2), vec3(0.1, 0.5, 0.9), clamp(s * 2.0, 0.0, 1.0));
		return mix(low, vec3(0.9, 0.97, 1.0), clamp(s * 2.0 - 1.0, 0.0, 1.0));
	} else if (palette == 3) {
		return cycle3(vec3(1.0, 0.1, 0.75), vec3(0.1, 0.9, 1.0), vec3(0.95, 1.0, 0.2), x);
	} else if (palette == 4) {
		return cycle3(colour_1.rgb, colour_2.rgb, colour_3.rgb, x);
	}
	return 0.5 + 0.5 * cos(6.2831853 * (x + vec3(0.0, 0.6666667, 0.3333333)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 lw = vec3(0.2126, 0.7152, 0.0722);
	float luma = dot(rgb, lw);
	float v = luma;
	if (input_from == 1) {
		v = hue_of(rgb);
	} else if (input_from == 2) {
		float mx = max(rgb.r, max(rgb.g, rgb.b));
		float mn = min(rgb.r, min(rgb.g, rgb.b));
		v = mx > 0.00001 ? (mx - mn) / mx : 0.0;
	} else if (input_from == 3) {
		v = rgb.r;
	} else if (input_from == 4) {
		v = rgb.g;
	} else if (input_from == 5) {
		v = rgb.b;
	}
	float x = fract(v * cycles + phase + max(clip_time, 0.0) * speed);
	vec3 pal = palette_at(x);
	if (keep_lightness) {
		float pl = dot(pal, lw);
		pal = pal + (luma - pl);
	}
	rgb = mix(pal, rgb, clamp(blend, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
