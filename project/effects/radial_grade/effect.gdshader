shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 centre = vec2(0.4, 0.45);
uniform float size : hint_range(0.02, 1.5) = 0.45;
uniform float stretch : hint_range(0.25, 4.0) = 0.85;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float feather : hint_range(0.0, 1.0) = 0.8;
uniform int where : hint_range(0, 1) = 0;
uniform float exposure : hint_range(-3.0, 3.0) = 0.5;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float temperature : hint_range(-1.0, 1.0) = 0.1;
uniform float tint : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform bool show_area = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float area(vec2 uv) {
	vec2 full = max(tex_size, vec2(1.0));
	vec2 d = (uv - centre) * full;
	float ang = radians(rotation);
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 l = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
	float r = max(size, 0.001) * full.y * 0.5;
	vec2 axes = vec2(r * max(stretch, 0.05), r);
	float e = length(l / axes);
	float fw = max(clamp(feather, 0.0, 1.0) * 0.9, 0.004);
	float inside = 1.0 - smoothstep(1.0 - fw * 0.5, 1.0 + fw * 0.5, e);
	return where == 0 ? inside : 1.0 - inside;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = to_linear(rgb) * exp2(exposure);
	lin *= vec3(1.0 + temperature * 0.35 - tint * 0.1, 1.0 + tint * 0.3, 1.0 - temperature * 0.35 - tint * 0.1);
	vec3 g = to_display(lin);
	g = clamp((g - 0.45) * contrast + 0.45, 0.0, 1.0);
	float y = dot(g, LUMA);
	g = clamp(vec3(y) + (g - vec3(y)) * saturation, 0.0, 1.0);
	float m = area(UV);
	vec3 outc = mix(rgb, g, m);
	if (show_area) {
		outc = mix(outc * 0.35, mix(outc, vec3(1.0, 0.45, 0.1), 0.35), m);
	}
	COLOR = vec4(outc * a, a);
}
