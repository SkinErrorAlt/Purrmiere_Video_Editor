shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D core_tex : filter_linear, repeat_disable;
uniform sampler2D halo_a : filter_linear, repeat_disable;
uniform sampler2D halo_b : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float size : hint_range(0.5, 6.0) = 2.5;
uniform float brightness : hint_range(0.0, 4.0) = 2.0;
uniform float halo : hint_range(0.0, 1.0) = 0.6;

vec3 dec(vec4 c) {
	return c.rgb * c.rgb * 2.0;
}

vec3 soft_add(vec3 base, vec3 add) {
	vec3 room = max(1.0 - base, vec3(0.001));
	return base + room * (1.0 - exp(-max(add, vec3(0.0)) / room));
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	vec2 full = vec2(textureSize(core_tex, 0));
	vec2 px = 1.0 / max(full, vec2(1.0));
	float ps = px_scale * full.x / max(tex_size.x, 1.0);
	float r = max(size * ps, 0.35);
	vec3 core = vec3(0.0);
	float wsum = 0.0;
	for (int j = -4; j <= 4; j++) {
		for (int i = -4; i <= 4; i++) {
			vec2 d = vec2(float(i), float(j));
			float dd = dot(d, d);
			float w = exp(-dd / (r * r));
			core += dec(texture(core_tex, UV + d * px)) * w;
			wsum += w;
		}
	}
	core *= 1.0 / max(wsum, 0.0001) * r * r * 3.0;
	vec3 glow = dec(texture(halo_a, UV)) * 6.0 + dec(texture(halo_b, UV)) * 14.0 + dec(texture(TEXTURE, UV)) * 30.0;
	vec3 add = (core + glow * clamp(halo, 0.0, 1.0)) * brightness;
	vec3 outc = soft_add(clamp(rgb, 0.0, 1.0), add * o.a);
	COLOR = vec4(outc * o.a, o.a);
}
