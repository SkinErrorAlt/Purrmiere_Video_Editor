shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int teeth : hint_range(1, 60) = 8;
uniform float tooth_height : hint_range(0.0, 0.5) = 0.08;
uniform int shape : hint_range(0, 2) = 0;

uniform bool vertical = false;

float edge(float x) {
	float f = fract(x * float(max(teeth, 1)));
	float w;
	if (shape == 1) { w = f < 0.5 ? 1.0 : -1.0; }
	else if (shape == 2) { w = cos(f * 6.2831853); }
	else { w = 1.0 - abs(f - 0.5) * 4.0; }
	return 0.5 + tooth_height * w;
}

void fragment() {
	vec2 q = vertical ? UV.yx : UV;
	float shift = progress * (0.5 + tooth_height + 0.001);
	vec2 st = q + vec2(0.0, shift);
	vec2 sb = q - vec2(0.0, shift);
	vec4 o = vec4(0.0);
	if (st.y <= 1.0 && st.y < edge(st.x)) {
		o = texture(TEXTURE, vertical ? st.yx : st);
	} else if (sb.y >= 0.0 && sb.y >= edge(sb.x)) {
		o = texture(TEXTURE, vertical ? sb.yx : sb);
	}
	COLOR = o;
}
