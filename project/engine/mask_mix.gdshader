shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;
uniform bool use_mask = true;
uniform bool have_effect_tex = true;
uniform int mode = 0;
uniform bool mask_invert = false;
uniform float mask_opacity = 1.0;
uniform vec4 mask_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 before_box = vec4(0.0, 0.0, 1.0, 1.0);

vec2 in_box(vec2 uv, vec4 box) {
	return (uv - box.xy) / max(box.zw, vec2(0.000001));
}

bool inside(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

void fragment() {
	vec4 after = texture(TEXTURE, UV);
	vec2 buv = in_box(UV, before_box);
	vec4 before = have_effect_tex ? (inside(buv) ? texture(effect_tex, buv) : vec4(0.0)) : after;
	vec2 muv = in_box(UV, mask_box);
	float m = 1.0;
	if (use_mask) {
		float raw = inside(muv) ? texture(mask_tex, muv).a : 0.0;
		m = (mask_invert && inside(muv) ? 1.0 - raw : raw) * clamp(mask_opacity, 0.0, 1.0);
	}
	if (mode == 1) {
		COLOR = after * m;
	} else if (mode == 2) {
		vec4 over = after + before * (1.0 - clamp(after.a, 0.0, 1.0));
		COLOR = mix(before, over, clamp(mix_amount, 0.0, 1.0));
	} else {
		m *= clamp(mix_amount, 0.0, 1.0);
		COLOR = mix(before, after, m);
	}
}
