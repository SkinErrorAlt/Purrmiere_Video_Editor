shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D spec_tex : filter_linear, repeat_disable;
uniform vec2 position = vec2(0.5, 0.92);
uniform float width : hint_range(0.05, 1.0) = 0.7;
uniform float height : hint_range(0.01, 1.0) = 0.35;
uniform float count : hint_range(4.0, 128.0) = 32.0;
uniform float gap : hint_range(0.0, 0.9) = 0.3;
uniform bool mirror = false;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 top_colour : source_color = vec4(1.0, 0.3, 0.55, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool peaks_on = false;
uniform vec4 peak_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float look_height_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 look_height_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform bool look_levels = false;
uniform vec4 look_low_colour : source_color = vec4(0.302, 0.553, 1.0, 0.85);
uniform vec4 look_high_colour : source_color = vec4(1.0, 0.302, 0.302, 0.85);
uniform float look_glow : hint_range(0.0, 1.0) = 0.0;
uniform float look_round : hint_range(0.0, 1.0) = 0.0;

float sd_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 size = max(tex_size, vec2(1.0));
	float left = position.x - width * 0.5;
	float u = (UV.x - left) / max(width, 0.0001);
	float a = 0.0;
	float a_glow = 0.0;
	float a_peak = 0.0;
	vec3 tint = colour.rgb;
	bool shaped = look_round > 0.0 || look_glow > 0.0;
	if ((u >= 0.0 && u <= 1.0) || shaped) {
		float n = max(floor(count), 1.0);
		float cell = clamp(u, 0.0, 0.99999) * n;
		float idx = floor(cell);
		vec4 d = texture(spec_tex, vec2((idx + 0.5) / n, 0.5));
		float v = clamp(d.r, 0.0, 1.0);
		float h = max(v * height, 2.0 / size.y);
		float aa = 1.0 / size.y;
		float rise = mirror ? abs(UV.y - position.y) : position.y - UV.y;
		float lim = mirror ? h * 0.5 : h;
		float cover = 0.0;
		if (shaped) {
			vec2 px = UV * size;
			float cell_w = width * size.x / n;
			float cx = (left + (idx + 0.5) / n * width) * size.x;
			float bw = max(cell_w * (1.0 - gap) * 0.5, 0.5);
			float hp = h * size.y;
			vec2 q = mirror ? vec2(px.x - cx, px.y - position.y * size.y) : vec2(px.x - cx, px.y - (position.y * size.y - hp * 0.5));
			vec2 hs = mirror ? vec2(bw, hp * 0.5) : vec2(bw, hp * 0.5);
			float dist = sd_box(q, hs, look_round * min(bw, hs.y));
			cover = 1.0 - smoothstep(-1.0, 1.0, dist);
			a_glow = look_glow > 0.0 ? look_glow * exp(-max(dist, 0.0) / max(18.0 * look_glow * px_scale, 0.5)) * 0.7 * (1.0 - cover) : 0.0;
		} else {
			float inside = step(gap * 0.5, fract(cell)) * step(fract(cell), 1.0 - gap * 0.5);
			cover = inside * step(-aa, rise) * (1.0 - smoothstep(lim - aa, lim + aa, rise));
		}
		float k = clamp(rise / max(height * (mirror ? 0.5 : 1.0), 0.0001), 0.0, 1.0);
		tint = mix(colour.rgb, top_colour.rgb, k);
		tint = mix(tint, look_height_colour.rgb, clamp(look_height_mix * k, 0.0, 1.0));
		if (look_levels) {
			tint = mix(tint, look_low_colour.rgb, clamp(d.b * look_low_colour.a, 0.0, 1.0));
			tint = mix(tint, look_high_colour.rgb, clamp(d.a * look_high_colour.a, 0.0, 1.0));
		}
		float alpha = mix(colour.a, top_colour.a, k);
		a = clamp(cover * alpha * opacity, 0.0, 1.0);
		a_glow = clamp(a_glow * alpha * opacity, 0.0, 1.0);
		if (peaks_on && u >= 0.0 && u <= 1.0) {
			float inside2 = step(gap * 0.5, fract(cell)) * step(fract(cell), 1.0 - gap * 0.5);
			float pk = clamp(d.g, 0.0, 1.0) * height;
			float plim = mirror ? pk * 0.5 : pk;
			float th = 2.0 / size.y;
			a_peak = clamp(inside2 * (1.0 - smoothstep(th * 0.5, th * 0.5 + aa, abs(rise - plim - th))) * peak_colour.a * opacity, 0.0, 1.0);
		}
	}
	vec4 out_c = base * (1.0 - a_glow) + vec4(tint * a_glow, a_glow);
	out_c = out_c * (1.0 - a) + vec4(tint * a, a);
	out_c = out_c * (1.0 - a_peak) + vec4(peak_colour.rgb * a_peak, a_peak);
	COLOR = out_c;
}
