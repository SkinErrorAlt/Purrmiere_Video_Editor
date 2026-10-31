shader_type canvas_item;
render_mode blend_disabled;

uniform bool invert = false;
uniform float low : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 1.0;
uniform bool keep_colour = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float span = max(high - low, 0.0001);
	float t = clamp((luma - low) / span, 0.0, 1.0);
	if (invert) {
		t = 1.0 - t;
	}
	float oa = a * t;
	vec3 o = keep_colour ? rgb : vec3(1.0);
	COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
}
