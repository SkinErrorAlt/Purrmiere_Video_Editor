shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 ref_centre = vec2(0.25, 0.5);
uniform float ref_width : hint_range(0.02, 1.0) = 0.46;
uniform float ref_height : hint_range(0.02, 1.0) = 0.9;
uniform vec2 target_centre = vec2(0.75, 0.5);
uniform float target_width : hint_range(0.02, 1.0) = 0.5;
uniform float target_height : hint_range(0.02, 1.0) = 1.0;
uniform float feather : hint_range(0.0, 0.2) = 0.0;
uniform int apply_to = 0;

const float ZERO = 128.0 / 255.0;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float cube_root(float x) {
	return sign(x) * pow(abs(x), 1.0 / 3.0);
}

vec3 to_oklab(vec3 rgb) {
	vec3 c = to_linear(rgb);
	float l = cube_root(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b);
	float m = cube_root(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b);
	float s = cube_root(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 from_oklab(vec3 lab) {
	float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
	l = l * l * l;
	m = m * m * m;
	s = s * s * s;
	vec3 c = vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
	return to_display(c);
}

float box_sdf(vec2 uv, vec2 centre, vec2 size, float asp) {
	vec2 p = (uv - centre) * vec2(asp, 1.0);
	vec2 hb = size * vec2(asp, 1.0) * 0.5;
	vec2 q = abs(p) - hb;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float asp = full.x / max(full.y, 1.0);
	float f = max(feather, 0.0005);
	float m = 0.0;
	if (apply_to == 0) {
		m = 1.0 - smoothstep(-f, 0.0, box_sdf(UV, target_centre, vec2(target_width, target_height), asp));
	} else {
		m = smoothstep(0.0, f, box_sdf(UV, ref_centre, vec2(ref_width, ref_height), asp));
	}
	float a = c.a;
	if (m <= 0.0 || a <= 0.0001) {
		COLOR = c;
	} else {
		vec3 rgb = c.rgb / a;
		ivec2 ts = textureSize(TEXTURE, 0);
		vec4 g4 = texelFetch(TEXTURE, ivec2(0, ts.y / 2), 0);
		vec4 o4 = texelFetch(TEXTURE, ivec2(max(ts.x - 1, 0), ts.y / 2), 0);
		vec3 gain = exp2((g4.rgb - ZERO) * 4.0);
		vec3 off = (o4.rgb - ZERO) * vec3(2.0, 1.0, 1.0);
		vec3 lab = to_oklab(rgb) * gain + off;
		lab.x = clamp(lab.x, 0.0, 1.0);
		vec3 matched = from_oklab(lab);
		rgb = mix(rgb, matched, clamp(m, 0.0, 1.0));
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
