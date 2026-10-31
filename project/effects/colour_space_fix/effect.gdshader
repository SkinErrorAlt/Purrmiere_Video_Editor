shader_type canvas_item;
render_mode blend_disabled;

uniform int problem : hint_range(0, 6) = 3;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const float LIMITED_LOW = 16.0 / 255.0;
const float LIMITED_SPAN = 219.0 / 255.0;

vec3 to_ycc(vec3 rgb, float kr, float kb) {
	float kg = 1.0 - kr - kb;
	float y = kr * rgb.r + kg * rgb.g + kb * rgb.b;
	return vec3(y, (rgb.b - y) / (2.0 * (1.0 - kb)), (rgb.r - y) / (2.0 * (1.0 - kr)));
}

vec3 from_ycc(vec3 ycc, float kr, float kb) {
	float kg = 1.0 - kr - kb;
	float r = ycc.x + 2.0 * (1.0 - kr) * ycc.z;
	float b = ycc.x + 2.0 * (1.0 - kb) * ycc.y;
	float g = (ycc.x - kr * r - kb * b) / kg;
	return vec3(r, g, b);
}

vec3 rematrix(vec3 rgb, vec2 read_as, vec2 recorded) {
	return from_ycc(to_ycc(rgb, read_as.x, read_as.y), recorded.x, recorded.y);
}

vec3 regamut(vec3 rgb, int which) {
	vec3 lin = pow(clamp(rgb, 0.0, 1.0), vec3(2.4));
	vec3 o;
	if (which == 0) {
		o = vec3(dot(lin, vec3(1.6605, -0.5876, -0.0728)), dot(lin, vec3(-0.1246, 1.1329, -0.0083)), dot(lin, vec3(-0.0182, -0.1006, 1.1187)));
	} else {
		o = vec3(dot(lin, vec3(1.2249, -0.2247, 0.0)), dot(lin, vec3(-0.0420, 1.0419, 0.0)), dot(lin, vec3(-0.0197, -0.0786, 1.0979)));
	}
	return pow(clamp(o, 0.0, 1.0), vec3(1.0 / 2.4));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec2 k601 = vec2(0.299, 0.114);
	vec2 k709 = vec2(0.2126, 0.0722);
	vec2 k2020 = vec2(0.2627, 0.0593);
	vec3 fixed_c = rgb;
	if (problem == 0) {
		fixed_c = rematrix(rgb, k709, k601);
	} else if (problem == 1) {
		fixed_c = rematrix(rgb, k601, k709);
	} else if (problem == 2) {
		fixed_c = rematrix(rgb, k709, k2020);
	} else if (problem == 3) {
		fixed_c = (rgb - vec3(LIMITED_LOW)) / LIMITED_SPAN;
	} else if (problem == 4) {
		fixed_c = vec3(LIMITED_LOW) + rgb * LIMITED_SPAN;
	} else if (problem == 5) {
		fixed_c = regamut(rgb, 0);
	} else {
		fixed_c = regamut(rgb, 1);
	}
	vec3 c = mix(rgb, clamp(fixed_c, 0.0, 1.0), clamp(strength, 0.0, 1.0));
	COLOR = vec4(clamp(c, 0.0, 1.0) * a, a);
}
