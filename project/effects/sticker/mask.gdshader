shader_type canvas_item;
render_mode blend_disabled;

uniform float px_scale = 1.0;
uniform float border : hint_range(0.0, 80.0) = 14.0;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	float u = (unpack16(d.rg) - unpack16(d.ba)) / max(px_scale, 0.0001);
	float m = 1.0 - smoothstep(border - 0.5, border + 0.5, u);
	COLOR = vec4(m, m, m, m);
}
