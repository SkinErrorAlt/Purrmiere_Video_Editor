shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float darkness : hint_range(0.0, 1.0) = 0.65;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float shrink : hint_range(0.0, 0.5) = 0.12;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float sc = max(1.0 - shrink, 0.05);
	vec2 pc = (UV - 0.5) / sc + 0.5;
	vec4 photo = vec4(0.0);
	if (pc.x >= 0.0 && pc.x <= 1.0 && pc.y >= 0.0 && pc.y <= 1.0) {
		photo = texture(effect_tex, pc);
	}
	float s = texture(TEXTURE, UV).r;
	s = clamp(s + (hash12(FRAGCOORD.xy) - 0.5) / 255.0 * step(0.004, s), 0.0, 1.0);
	float sa = s * clamp(darkness, 0.0, 1.0) * colour.a;
	vec4 sh = vec4(colour.rgb * sa, sa);
	COLOR = photo + sh * (1.0 - photo.a);
}
