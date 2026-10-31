shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 region_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float region_rot = 0.0;
uniform vec2 src_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 uv = region_rect.xy + UV * region_rect.zw;
	if (abs(region_rot) >= 0.0001) {
		vec2 p = (UV - 0.5) * region_rect.zw * src_size;
		float ca = cos(region_rot);
		float sa = sin(region_rot);
		vec2 rp = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
		uv = (region_rect.xy + region_rect.zw * 0.5) + rp / max(src_size, vec2(1.0));
	}
	COLOR = texture(TEXTURE, uv);
}
