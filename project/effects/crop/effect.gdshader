shader_type canvas_item;
render_mode blend_disabled;

uniform float left : hint_range(0.0, 1.0) = 0.0;
uniform float top : hint_range(0.0, 1.0) = 0.0;
uniform float right : hint_range(0.0, 1.0) = 0.0;
uniform float bottom : hint_range(0.0, 1.0) = 0.0;
uniform float feather : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float f = max(feather, 0.0001);
	float m = smoothstep(left, left + f, UV.x) * smoothstep(1.0 - right, 1.0 - right - f, UV.x);
	m *= smoothstep(top, top + f, UV.y) * smoothstep(1.0 - bottom, 1.0 - bottom - f, UV.y);
	if (feather <= 0.0) {
		m = (UV.x >= left && UV.x <= 1.0 - right && UV.y >= top && UV.y <= 1.0 - bottom) ? 1.0 : 0.0;
	}
	COLOR = c * m;
}
