shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float distance : hint_range(0.0, 200.0) = 8.0;
uniform float angle : hint_range(-180.0, 180.0) = 135.0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float a = radians(angle);
	vec2 off = vec2(cos(a), -sin(a)) * distance * px_scale / tex_size;
	vec2 uv = UV - off;
	float alpha = 0.0;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		alpha = texture(TEXTURE, uv).a;
	}
	float sa = alpha * colour.a * opacity;
	COLOR = vec4(colour.rgb * sa, sa);
}
