shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(2, 16) = 5;
uniform float edge_width : hint_range(0.0, 8.0) = 1.5;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.2;
uniform vec4 edge_colour : source_color = vec4(0.05, 0.04, 0.06, 1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

#define LUMA(p) dot(texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0))).rgb, vec3(0.2126, 0.7152, 0.0722))

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

vec3 to_oklab(vec3 srgb) {
	vec3 c = srgb_to_linear(srgb);
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(max(l, 0.0), 1.0 / 3.0);
	m = pow(max(m, 0.0), 1.0 / 3.0);
	s = pow(max(s, 0.0), 1.0 / 3.0);
	return vec3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 from_oklab(vec3 lab) {
	float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
	l = l * l * l;
	m = m * m * m;
	s = s * s * s;
	vec3 lin = vec3(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
	return linear_to_srgb(lin);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 lab = to_oklab(rgb);
	float n = float(max(levels, 2) - 1);
	float v = clamp(lab.x, 0.0, 1.0) * n;
	float w = clamp(fwidth(v), 0.001, 0.5);
	float q = floor(v) + smoothstep(0.5 - w, 0.5 + w, fract(v));
	lab.x = mix(0.1, 0.98, q / n);
	lab.yz *= saturation;
	rgb = from_oklab(lab);
	if (edge_width > 0.0) {
		vec2 e = vec2(edge_width * px_scale) / dims;
		float tl = LUMA(UV + vec2(-e.x, -e.y));
		float tc = LUMA(UV + vec2(0.0, -e.y));
		float tr = LUMA(UV + vec2(e.x, -e.y));
		float ml = LUMA(UV + vec2(-e.x, 0.0));
		float mr = LUMA(UV + vec2(e.x, 0.0));
		float bl = LUMA(UV + vec2(-e.x, e.y));
		float bc = LUMA(UV + vec2(0.0, e.y));
		float br = LUMA(UV + vec2(e.x, e.y));
		float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
		float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
		float g = length(vec2(gx, gy)) * 0.25;
		float ink = smoothstep(edge_threshold, edge_threshold + 0.1, g);
		rgb = mix(rgb, edge_colour.rgb, ink * edge_colour.a);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
