shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 region_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float region_rot = 0.0;
uniform vec2 src_size = vec2(1920.0, 1080.0);
uniform sampler2D base_tex : filter_linear, repeat_disable;

void fragment() {
	vec2 size = max(region_rect.zw, vec2(0.000001));
	vec2 local = (UV - region_rect.xy) / size;
	if (abs(region_rot) >= 0.0001) {
		vec2 d = (UV - (region_rect.xy + region_rect.zw * 0.5)) * src_size;
		float ca = cos(-region_rot);
		float sa = sin(-region_rot);
		vec2 p = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
		local = p / max(size * src_size, vec2(0.000001)) + 0.5;
	}
	if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0) {
		COLOR = texture(base_tex, UV);
	} else {
		COLOR = texture(TEXTURE, local);
	}
}
