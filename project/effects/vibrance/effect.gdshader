shader_type canvas_item;
render_mode blend_disabled;

uniform float vibrance : hint_range(-1.0, 2.0) = 0.4;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float protect_skin : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat = mx - mn;
	float skin = clamp(1.0 - abs(rgb.r - mx) * 4.0, 0.0, 1.0) * clamp(rgb.r - rgb.b, 0.0, 1.0);
	float hold = 1.0 - skin * protect_skin;
	float push = 1.0 + vibrance * (1.0 - sat) * hold;
	rgb = vec3(luma) + (rgb - vec3(luma)) * push * saturation;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
