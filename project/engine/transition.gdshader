shader_type canvas_item;
render_mode blend_disabled;

uniform int kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.5) = 0.045;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0;
	if (kind == 1) {
		a = progress;
	} else if (kind == 2 || kind == 3) {
		a = progress < 0.5 ? 0.0 : (progress - 0.5) * 2.0;
	} else if (kind >= 4 && kind <= 7) {
		float x = UV.x;
		if (kind == 4) {
			x = 1.0 - UV.x;
		} else if (kind == 6) {
			x = 1.0 - UV.y;
		} else if (kind == 7) {
			x = UV.y;
		}
		float edge = progress * (1.0 + softness * 2.0) - softness;
		a = 1.0 - smoothstep(edge - softness, edge + softness, x);
	}
	COLOR = c * a;
}
