shader_type canvas_item;
render_mode blend_disabled;

uniform float left : hint_range(0.0, 0.5) = 0.05;
uniform float right : hint_range(0.0, 0.5) = 0.05;
uniform float top : hint_range(0.0, 0.5) = 0.05;
uniform float bottom : hint_range(0.0, 0.5) = 0.05;
uniform float rounded : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float fl = left > 0.0001 ? smoothstep(0.0, left, UV.x) : 1.0;
	float fr = right > 0.0001 ? smoothstep(0.0, right, 1.0 - UV.x) : 1.0;
	float ft = top > 0.0001 ? smoothstep(0.0, top, UV.y) : 1.0;
	float fb = bottom > 0.0001 ? smoothstep(0.0, bottom, 1.0 - UV.y) : 1.0;
	float keep = fl * fr * ft * fb;
	if (rounded > 0.0001) {
		vec2 p = abs(UV - 0.5) * 2.0;
		float corner = length(max(p - (1.0 - rounded * 2.0), vec2(0.0))) / max(rounded * 2.0, 0.0001);
		keep *= 1.0 - smoothstep(0.7, 1.0, corner);
	}
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
