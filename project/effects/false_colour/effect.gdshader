shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 2) = 0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool show_picture = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const vec3 PURPLE = vec3(0.55, 0.0, 0.65);
const vec3 BLUE = vec3(0.0, 0.35, 1.0);
const vec3 DARK_GREY = vec3(0.2);
const vec3 MID_GREY = vec3(0.45);
const vec3 GREEN = vec3(0.1, 0.8, 0.2);
const vec3 PINK = vec3(1.0, 0.5, 0.72);
const vec3 LIGHT_GREY = vec3(0.75);
const vec3 YELLOW = vec3(1.0, 0.92, 0.0);
const vec3 RED = vec3(1.0, 0.0, 0.0);

vec3 heat(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = mix(vec3(0.0), vec3(0.1, 0.1, 0.9), smoothstep(0.0, 0.2, t));
	c = mix(c, vec3(0.0, 0.8, 0.9), smoothstep(0.2, 0.4, t));
	c = mix(c, vec3(0.1, 0.85, 0.2), smoothstep(0.4, 0.55, t));
	c = mix(c, vec3(1.0, 0.9, 0.0), smoothstep(0.55, 0.7, t));
	c = mix(c, vec3(1.0, 0.1, 0.0), smoothstep(0.7, 0.88, t));
	c = mix(c, vec3(1.0), smoothstep(0.88, 1.0, t));
	return c;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	float y = dot(rgb, LUMA);
	float ire = y * 100.0;
	vec3 grey_pic = vec3(y);
	vec3 shown = rgb;
	if (mode == 0) {
		vec3 band = RED;
		bool coloured = true;
		if (ire < 2.0) {
			band = PURPLE;
		} else if (ire < 10.0) {
			band = BLUE;
		} else if (ire < 20.0) {
			band = DARK_GREY;
			coloured = false;
		} else if (ire < 42.0) {
			band = MID_GREY;
			coloured = false;
		} else if (ire < 52.0) {
			band = GREEN;
		} else if (ire < 56.0) {
			band = MID_GREY;
			coloured = false;
		} else if (ire < 62.0) {
			band = PINK;
		} else if (ire < 94.0) {
			band = LIGHT_GREY;
			coloured = false;
		} else if (ire < 99.0) {
			band = YELLOW;
		}
		if (show_picture) {
			shown = coloured ? mix(grey_pic, band, 0.75) : grey_pic;
		} else {
			shown = band;
		}
	} else if (mode == 1) {
		shown = show_picture ? mix(grey_pic, heat(y), 0.6) : heat(y);
	} else {
		shown = show_picture ? grey_pic : rgb;
		if (ire > 99.0) {
			shown = RED;
		} else if (ire < 2.0) {
			shown = PURPLE;
		}
	}
	rgb = mix(rgb, shown, opacity);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
