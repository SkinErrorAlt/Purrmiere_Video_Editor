shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float detail : hint_range(1.0, 15.0) = 13.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform vec4 dark_colour : source_color = vec4(0.25, 0.23, 0.21, 1.0);
uniform vec4 light_colour : source_color = vec4(0.92, 0.9, 0.86, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

#define L(o) lum(texture(TEXTURE, UV + (o)))

void fragment() {
	float a = texture(effect_tex, UV).a;
	float ps = max(px_scale, 0.0001);
	vec2 e = vec2(1.2 * ps) / max(tex_size, vec2(1.0));
	float l0 = L(vec2(0.0));
	float gx = (L(vec2(e.x, 0.0)) - L(vec2(-e.x, 0.0))) / 2.4;
	float gy = (L(vec2(0.0, e.y)) - L(vec2(0.0, -e.y))) / 2.4;
	float ang = radians(light_angle);
	vec2 ld = vec2(cos(ang), -sin(ang));
	float lit = -(gx * ld.x + gy * ld.y);
	float v = clamp(0.5 + (l0 - 0.5) * 0.45 + lit * detail * 1.2, 0.0, 1.0);
	vec3 outc = mix(dark_colour.rgb, light_colour.rgb, v);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
