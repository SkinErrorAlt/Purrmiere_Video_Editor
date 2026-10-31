shader_type canvas_item;
render_mode blend_add;

uniform float weight : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float aw = c.a * weight;
	if (aw <= 0.000001) {
		COLOR = vec4(0.0);
	} else {
		float s = sqrt(aw);
		COLOR = vec4(c.rgb * weight / s, s);
	}
}
