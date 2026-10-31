shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float feather : hint_range(0.0, 1.0) = 0.05;
uniform bool invert = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	float t = dot(UV - vec2(0.5), dir) + 0.5;
	float soft = max(feather, 0.0001);
	float keep = smoothstep(progress + soft, progress - soft, t);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
