shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D wave_tex : filter_linear, repeat_disable;
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.75, 1.0);
uniform float position : hint_range(0.0, 1.0) = 0.8;
uniform float width : hint_range(0.05, 1.0) = 0.9;
uniform float height : hint_range(0.01, 1.0) = 0.3;
uniform float thickness : hint_range(0.5, 40.0) = 4.0;
uniform int style : hint_range(0, 2) = 0;
uniform float bars : hint_range(4.0, 256.0) = 64.0;
uniform float gap : hint_range(0.0, 0.9) = 0.3;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
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
	float left = 0.5 - width * 0.5;
	float u = (UV.x - left) / max(width, 0.0001);
	float cover = 0.0;
	float edge = 1e9;
	vec4 d = vec4(0.0);
	if (u >= 0.0 && u <= 1.0) {
		float aa = 1.5 / size.y;
		if (style == 2) {
			float n = max(floor(bars), 1.0);
			float cell = u * n;
			float idx = floor(cell);
			float inside = step(gap * 0.5, fract(cell)) * step(fract(cell), 1.0 - gap * 0.5);
			d = texture(wave_tex, vec2((idx + 0.5) / n, 0.5));
			float v = d.r;
			float half_h = max(v * height * 0.5, 1.0 / size.y);
			float dy = abs(UV.y - position);
			if (look_round > 0.0) {
				float bw = (1.0 - gap) * 0.5 / n * width * size.x;
				float rr = look_round * min(bw, half_h * size.y);
				vec2 q = abs(vec2((fract(cell) - 0.5) / n * width * size.x, dy * size.y)) - vec2(bw, half_h * size.y) + vec2(rr);
				float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - rr;
				cover = 1.0 - smoothstep(-1.0, 1.0, sd);
			} else {
				cover = inside * (1.0 - smoothstep(half_h - aa, half_h + aa, dy));
			}
			edge = (dy - half_h) * size.y;
		} else if (style == 1) {
			d = texture(wave_tex, vec2(u, 0.5));
			float v = d.r;
			float y = position - v * height * 0.5;
			float th = max(thickness * px_scale, 1.0) / size.y;
			float dy = abs(UV.y - y);
			cover = 1.0 - smoothstep(th * 0.5 - aa, th * 0.5 + aa, dy);
			edge = (dy - th * 0.5) * size.y;
		} else {
			d = texture(wave_tex, vec2(u, 0.5));
			float v = d.r;
			float half_h = max(v * height * 0.5, 1.0 / size.y);
			float dy = abs(UV.y - position);
			cover = 1.0 - smoothstep(half_h - aa, half_h + aa, dy);
			edge = (dy - half_h) * size.y;
		}
	}
	float k = clamp(abs(UV.y - position) / max(height * 0.5, 0.0001), 0.0, 1.0);
	vec3 tint = mix(colour.rgb, look_height_colour.rgb, clamp(look_height_mix * k, 0.0, 1.0));
	if (look_levels) {
		tint = mix(tint, look_low_colour.rgb, clamp(d.b * look_low_colour.a, 0.0, 1.0));
		tint = mix(tint, look_high_colour.rgb, clamp(d.a * look_high_colour.a, 0.0, 1.0));
	}
	float a = clamp(cover * colour.a * opacity, 0.0, 1.0);
	float a_glow = look_glow > 0.0 ? clamp(look_glow * exp(-max(edge, 0.0) / max(18.0 * look_glow * px_scale, 0.5)) * 0.7 * (1.0 - cover) * colour.a * opacity, 0.0, 1.0) : 0.0;
	vec4 out_c = base * (1.0 - a_glow) + vec4(tint * a_glow, a_glow);
	COLOR = out_c * (1.0 - a) + vec4(tint * a, a);
}
