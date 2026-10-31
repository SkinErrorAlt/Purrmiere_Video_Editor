shader_type canvas_item;
render_mode blend_disabled;

uniform float clip_black : hint_range(0.0, 1.0) = 0.1;
uniform float clip_white : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float m = 0.0;
	if (clip_white > clip_black + 0.001) {
		m = clamp((a - clip_black) / (clip_white - clip_black), 0.0, 1.0);
	} else {
		m = step(clip_black - 0.001, a);
	}
	COLOR = vec4(m, m, m, m);
}
