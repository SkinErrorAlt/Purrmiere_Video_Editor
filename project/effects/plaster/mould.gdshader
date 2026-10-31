shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float image_balance : hint_range(0.0, 50.0) = 20.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 90.0;
uniform vec4 plaster_colour : source_color = vec4(0.93, 0.92, 0.89, 1.0);
uniform vec4 raised_colour : source_color = vec4(0.2, 0.19, 0.19, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float height(vec4 c, float b) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return 1.0 - smoothstep(b - 0.05, b + 0.05, dot(rgb, vec3(0.2126, 0.7152, 0.0722)));
}

#define H(o) height(texture(TEXTURE, UV + (o)), b)

void fragment() {
	float a = texture(effect_tex, UV).a;
	float ps = max(px_scale, 0.0001);
	vec2 e = vec2(1.5 * ps) / max(tex_size, vec2(1.0));
	float b = 0.1 + image_balance / 50.0 * 0.7;
	float h0 = H(vec2(0.0));
	float gx = (H(vec2(e.x, 0.0)) - H(vec2(-e.x, 0.0))) / 3.0;
	float gy = (H(vec2(0.0, e.y)) - H(vec2(0.0, -e.y))) / 3.0;
	vec3 n = normalize(vec3(-gx * 14.0, -gy * 14.0, 1.0));
	float ang = radians(light_angle);
	vec3 ld = normalize(vec3(cos(ang), -sin(ang), 0.9));
	float diff = max(dot(n, ld), 0.0) / ld.z;
	float spec = pow(max(dot(reflect(-ld, n), vec3(0.0, 0.0, 1.0)), 0.0), 10.0);
	float rim = 1.0 - n.z;
	vec3 base = mix(plaster_colour.rgb, raised_colour.rgb, h0);
	vec3 outc = base * mix(1.0, diff, 0.85) + vec3(spec) * smoothstep(0.0, 0.25, rim) * 0.85;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
