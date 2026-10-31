shader_type canvas_item;
render_mode blend_disabled;

uniform bool horizontal = true;
uniform bool vertical = false;

void fragment() {
	vec2 uv = UV;
	if (horizontal) {
		uv.x = 1.0 - uv.x;
	}
	if (vertical) {
		uv.y = 1.0 - uv.y;
	}
	COLOR = texture(TEXTURE, uv);
}
