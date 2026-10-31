shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float position : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.0, 1.0) = 0.35;
uniform float exposure : hint_range(-4.0, 4.0) = -1.0;
uniform vec4 colour : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform float colour_amount : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform float contrast : hint_range(-1.0, 1.0) = 0.1;
uniform bool show_mask = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 asp = vec2(size.x / size.y, 1.0);
	float th = radians(angle);
	vec2 dir = vec2(sin(th), -cos(th));
	vec2 p = (UV - 0.5) * asp;
	float reach = 0.5 * (abs(dir.x) * asp.x + abs(dir.y));
	float along = dot(p, dir) / max(reach, 0.0001);
	float edge = 1.0 - 2.0 * clamp(position, 0.0, 1.0);
	float half_w = max(clamp(softness, 0.0, 1.0), 0.002);
	float w = smoothstep(edge - half_w, edge + half_w, along);
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 g = rgb * exp2(exposure * w);
	vec3 tint = clamp(colour.rgb, 0.0, 1.0);
	tint = tint / max(dot(tint, LUMA), 0.05);
	g = mix(g, g * tint, clamp(colour_amount, 0.0, 1.0) * w);
	float l = dot(g, LUMA);
	g = vec3(l) + (g - vec3(l)) * mix(1.0, clamp(saturation, 0.0, 2.0), w);
	vec3 x = clamp(g, 0.0, 1.0);
	g += clamp(contrast, -1.0, 1.0) * w * (x * x * (3.0 - 2.0 * x) - x);
	g = clamp(g, 0.0, 1.0);
	if (show_mask) {
		g = mix(g * 0.35, vec3(1.0, 0.35, 0.2), w * 0.6);
	}
	COLOR = vec4(g * a, a);
}
