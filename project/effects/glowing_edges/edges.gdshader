shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float edge_width : hint_range(1.0, 14.0) = 2.0;
uniform float edge_brightness : hint_range(0.0, 20.0) = 6.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

#define col(uv) unpremul(texture(TEXTURE, uv))

void fragment() {
	float a = texture(effect_tex, UV).a;
	vec2 d = vec2(max(edge_width * 0.6 * max(px_scale, 0.0001), 0.6)) / max(tex_size, vec2(1.0));
	vec3 tl = col(UV + vec2(-d.x, -d.y));
	vec3 tc = col(UV + vec2(0.0, -d.y));
	vec3 tr = col(UV + vec2(d.x, -d.y));
	vec3 ml = col(UV + vec2(-d.x, 0.0));
	vec3 mr = col(UV + vec2(d.x, 0.0));
	vec3 bl = col(UV + vec2(-d.x, d.y));
	vec3 bc = col(UV + vec2(0.0, d.y));
	vec3 br = col(UV + vec2(d.x, d.y));
	vec3 gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	vec3 gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	vec3 g = sqrt(gx * gx + gy * gy) * 0.25;
	g = max(g - 0.004, vec3(0.0));
	vec3 glow = vec3(1.0) - exp(-g * edge_brightness * 1.1);
	COLOR = vec4(clamp(glow, 0.0, 1.0) * a, a);
}
