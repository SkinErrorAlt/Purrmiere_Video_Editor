shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float start_angle : hint_range(-180.0, 180.0) = -90.0;
uniform float feather : hint_range(0.0, 0.5) = 0.02;
uniform bool anticlockwise = false;
uniform vec2 centre = vec2(0.5, 0.5);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 d = UV - centre;
	float ang = atan(d.y, d.x) - radians(start_angle);
	float t = fract(ang / 6.28318530718 + 1.0);
	if (anticlockwise) { t = 1.0 - t; }
	float soft = max(feather, 0.0001);
	float keep = smoothstep(progress + soft, progress - soft, t);
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
