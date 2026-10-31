shader_type canvas_item;
render_mode blend_disabled;

uniform vec3 shadow = vec3(0.0);
uniform vec3 midtone = vec3(0.0);
uniform vec3 highlight = vec3(0.0);
uniform float low_range : hint_range(0.0, 1.0) = 0.33;
uniform float high_range : hint_range(0.0, 1.0) = 0.55;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float pivot : hint_range(0.0, 1.0) = 0.435;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float ws = 1.0 - smoothstep(low_range - 0.12, low_range + 0.12, l);
	float wh = smoothstep(high_range - 0.12, high_range + 0.12, l);
	float wm = clamp(1.0 - ws - wh, 0.0, 1.0);
	rgb += shadow * ws + midtone * wm + highlight * wh;
	rgb = (rgb - pivot) * contrast + pivot;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
