shader_type canvas_item;
render_mode blend_disabled;

uniform float high : hint_range(0.5, 1.0) = 0.95;
uniform float low : hint_range(0.0, 0.5) = 0.05;
uniform float stripe_width : hint_range(1.0, 50.0) = 6.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform vec4 high_colour : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 low_colour : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform bool show_low = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	float y = dot(rgb, LUMA);
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	float w = max(stripe_width * px_scale, 0.5);
	float pos = dot(UV * tex_size, dir) / (2.0 * w) - clip_time * speed;
	float tri = abs(fract(pos) - 0.5) * 2.0;
	float aa = clamp(0.5 / w, 0.001, 0.5);
	float stripe = smoothstep(0.5 - aa, 0.5 + aa, tri);
	float over = y >= high ? 1.0 : 0.0;
	float under = (show_low && y <= low) ? 1.0 : 0.0;
	rgb = mix(rgb, high_colour.rgb, over * stripe * high_colour.a);
	rgb = mix(rgb, low_colour.rgb, under * stripe * low_colour.a);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
