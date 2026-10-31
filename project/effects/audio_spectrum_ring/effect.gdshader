shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform sampler2D spec_tex : filter_linear, repeat_disable;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius : hint_range(0.02, 0.6) = 0.18;
uniform float reach : hint_range(0.01, 0.6) = 0.16;
uniform float count : hint_range(8.0, 256.0) = 72.0;
uniform float gap : hint_range(0.0, 0.9) = 0.35;
uniform float ring : hint_range(0.0, 0.05) = 0.006;
uniform float spin : hint_range(-2.0, 2.0) = 0.05;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.15;
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.75, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float px_scale = 1.0;
uniform float look_height_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 look_height_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform bool look_levels = false;
uniform vec4 look_low_colour : source_color = vec4(0.302, 0.553, 1.0, 0.85);
uniform vec4 look_high_colour : source_color = vec4(1.0, 0.302, 0.302, 0.85);
uniform float look_glow : hint_range(0.0, 1.0) = 0.0;
uniform float look_round : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 size = max(tex_size, vec2(1.0));
	float unit = min(size.x, size.y);
	vec2 p = (UV - centre) * size / unit;
	float r = length(p);
	float ang = atan(p.x, -p.y) / 6.28318530718 + 0.5 + clip_time * spin;
	float f = fract(ang);
	float n = max(floor(count), 1.0);
	float cell = f * n;
	float idx = floor(cell);
	float mid = (idx + 0.5) / n;
	float u = 1.0 - abs(mid * 2.0 - 1.0);
	vec4 d = texture(spec_tex, vec2(u, 0.5));
	float v = clamp(d.r, 0.0, 1.0);
	float r0 = radius * (1.0 + pulse * level);
	float aa = 1.5 / unit;
	float inside = step(gap * 0.5, fract(cell)) * step(fract(cell), 1.0 - gap * 0.5);
	float len = max(v * reach, 1.5 / unit);
	float bar = inside * smoothstep(r0 - aa, r0, r) * (1.0 - smoothstep(r0 + len, r0 + len + aa, r));
	float circle = ring > 0.0 ? 1.0 - smoothstep(ring * 0.5, ring * 0.5 + aa, abs(r - r0 + ring)) : 0.0;
	float k = clamp((r - r0) / max(reach, 0.0001), 0.0, 1.0);
	vec3 tint = mix(colour.rgb, look_height_colour.rgb, clamp(look_height_mix * k, 0.0, 1.0));
	if (look_levels) {
		tint = mix(tint, look_low_colour.rgb, clamp(d.b * look_low_colour.a, 0.0, 1.0));
		tint = mix(tint, look_high_colour.rgb, clamp(d.a * look_high_colour.a, 0.0, 1.0));
	}
	if (look_round > 0.0 && inside > 0.5) {
		float cw = 6.28318530718 * r * (1.0 - gap) / n * 0.5;
		float tip = r0 + len - cw * look_round;
		vec2 tp = vec2((fract(cell) - 0.5) * 6.28318530718 * r / n, r - tip);
		bar = r > tip ? inside * (1.0 - smoothstep(cw - aa, cw + aa, length(tp))) * step(r0, r) : bar;
	}
	float shape = max(bar, circle);
	float a = clamp(shape * colour.a * opacity, 0.0, 1.0);
	float outside = max(r - (r0 + len), 0.0) * unit;
	float a_glow = look_glow > 0.0 ? clamp(look_glow * exp(-outside / max(18.0 * look_glow * px_scale, 0.5)) * 0.7 * (1.0 - shape) * step(r0, r) * colour.a * opacity, 0.0, 1.0) : 0.0;
	vec4 out_c = base * (1.0 - a_glow) + vec4(tint * a_glow, a_glow);
	COLOR = out_c * (1.0 - a) + vec4(tint * a, a);
}
