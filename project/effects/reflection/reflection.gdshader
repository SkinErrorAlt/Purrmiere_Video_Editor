shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float edge : hint_range(0.0, 1.0) = 0.65;
uniform bool above = false;
uniform float fade_length : hint_range(0.01, 1.0) = 0.3;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform float blur : hint_range(0.0, 60.0) = 10.0;
uniform float gap : hint_range(0.0, 400.0) = 0.0;
uniform bool keep_under = false;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float y = above ? 1.0 - UV.y : UV.y;
	float e = above ? 1.0 - edge : edge;
	float gap_uv = gap * px_scale / size.y;
	vec4 base = c;
	if (!keep_under && y > e) {
		base = vec4(0.0);
	}
	vec4 outc = base;
	float dist = y - e - gap_uv;
	if (dist >= 0.0) {
		float src = e - dist;
		if (src >= 0.0) {
			float t = clamp(dist / max(fade_length, 0.001), 0.0, 1.0);
			float fall = clamp(opacity, 0.0, 1.0) * (1.0 - t) * (1.0 - t);
			float r = blur * px_scale * t;
			vec4 refl = vec4(0.0);
			if (r < 0.5) {
				float sy = above ? 1.0 - src : src;
				refl = texture(TEXTURE, vec2(UV.x, clamp(sy, 0.0, 1.0)));
			} else {
				float wsum = 0.0;
				for (int i = 0; i < 13; i++) {
					float fi = float(i);
					float rr = i == 0 ? 0.0 : sqrt(fi / 12.0) * r;
					float ang = fi * 2.39996323;
					vec2 o = vec2(cos(ang), sin(ang)) * rr / size;
					float ty = clamp(src + o.y, 0.0, e);
					float sy = above ? 1.0 - ty : ty;
					refl += texture(TEXTURE, clamp(vec2(UV.x + o.x, sy), vec2(0.0), vec2(1.0)));
					wsum += 1.0;
				}
				refl /= wsum;
			}
			refl *= fall;
			outc = refl + base * (1.0 - refl.a);
		}
	}
	COLOR = outc;
}
