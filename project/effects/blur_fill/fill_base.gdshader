shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform int fill = 0;
uniform float zoom : hint_range(1.0, 3.0) = 1.1;
uniform float size : hint_range(0.2, 2.0) = 1.0;
uniform vec2 position = vec2(0.5, 0.5);

vec2 fill_uv(vec2 uv) {
	vec2 sz = max(source_box.zw, vec2(0.0001));
	float z = max(zoom, 1.0);
	if (fill == 1 || fill == 2) {
		vec2 box = sz * max(size, 0.01) * z;
		vec2 f = (uv - position) / box + 0.5;
		if (fill == 1) {
			return 1.0 - abs(1.0 - mod(f, 2.0));
		}
		return clamp(f, vec2(0.0), vec2(1.0));
	}
	float k = max(1.0 / sz.x, 1.0 / sz.y) * z;
	return 0.5 + (uv - 0.5) / (sz * k);
}

void fragment() {
	vec2 d = fwidth(UV) * 0.25;
	vec4 s = texture(TEXTURE, fill_uv(UV + vec2(-d.x, -d.y)));
	s += texture(TEXTURE, fill_uv(UV + vec2(d.x, -d.y)));
	s += texture(TEXTURE, fill_uv(UV + vec2(-d.x, d.y)));
	s += texture(TEXTURE, fill_uv(UV + vec2(d.x, d.y)));
	COLOR = s * 0.25;
}
