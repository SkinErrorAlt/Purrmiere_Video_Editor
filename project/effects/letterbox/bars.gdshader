shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int aspect : hint_range(0, 9) = 0;
uniform float custom_aspect : hint_range(0.2, 5.0) = 2.0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness : hint_range(0.0, 200.0) = 0.0;
uniform float offset : hint_range(-1.0, 1.0) = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform bool transparent = false;

const float RATIOS[9] = float[9](2.39, 2.35, 2.0, 1.85, 1.66, 1.3333333, 1.0, 0.8, 0.5625);

float bar_edge(float x, float edge_pos, float soft) {
	float s = max(min(soft, 2.0 * edge_pos), 0.00001);
	float v = clamp((edge_pos - x) / s + 0.5, 0.0, 1.0);
	return v * v * (3.0 - 2.0 * v);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float target = aspect >= 9 ? custom_aspect : RATIOS[clamp(aspect, 0, 8)];
	target = max(target, 0.01);
	float pic = size.x / size.y;
	float amt = clamp(amount, 0.0, 1.0);
	float off = clamp(offset, -1.0, 1.0);
	float bar = 0.0;
	if (target >= pic) {
		float room = 1.0 - pic / target;
		float first = room * 0.5 * (1.0 + off) * amt;
		float second = room * 0.5 * (1.0 - off) * amt;
		float soft = max(softness * px_scale, 1.0) / size.y;
		bar = max(bar_edge(UV.y, first, soft), bar_edge(1.0 - UV.y, second, soft));
	} else {
		float room = 1.0 - target / pic;
		float first = room * 0.5 * (1.0 + off) * amt;
		float second = room * 0.5 * (1.0 - off) * amt;
		float soft = max(softness * px_scale, 1.0) / size.x;
		bar = max(bar_edge(UV.x, first, soft), bar_edge(1.0 - UV.x, second, soft));
	}
	vec4 c = texture(TEXTURE, UV);
	vec4 bar_c = vec4(colour.rgb * colour.a, colour.a);
	vec4 covered = transparent ? vec4(0.0) : bar_c + c * (1.0 - bar_c.a);
	COLOR = mix(c, covered, bar);
}
