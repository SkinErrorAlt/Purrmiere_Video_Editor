shader_type canvas_item;
render_mode blend_disabled;

uniform int corner : hint_range(0, 3) = 0;
uniform float size : hint_range(0.005, 0.1) = 0.022;
uniform float margin : hint_range(0.0, 0.2) = 0.06;
uniform vec4 colour : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float blink : hint_range(0.0, 4.0) = 1.0;
uniform bool brackets = true;
uniform vec4 bracket_colour : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float bracket_size : hint_range(0.02, 0.3) = 0.08;
uniform float line : hint_range(0.5, 12.0) = 3.0;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	vec2 at = vec2(UV.x * asp, UV.y);
	float px = 1.0 / sz.y;
	vec3 rgb = c.rgb;
	float al = c.a;
	if (brackets) {
		float lw = line * px_scale * px;
		vec2 q = vec2(min(at.x, asp - at.x), min(at.y, 1.0 - at.y)) - vec2(margin * 0.5);
		bool arm_h = q.y >= 0.0 && q.y <= lw && q.x >= 0.0 && q.x <= bracket_size;
		bool arm_v = q.x >= 0.0 && q.x <= lw && q.y >= 0.0 && q.y <= bracket_size;
		if (arm_h || arm_v) {
			float a = bracket_colour.a;
			rgb = rgb * (1.0 - a) + bracket_colour.rgb * a;
			al = al + a * (1.0 - al);
		}
	}
	bool rightside = corner == 1 || corner == 3;
	bool bottom = corner == 2 || corner == 3;
	float off = margin + size * 1.5;
	vec2 ctr = vec2(rightside ? asp - off : off, bottom ? 1.0 - off : off);
	float on = blink > 0.0 ? smoothstep(0.35, 0.45, fract(clip_time * blink + 0.5)) : 1.0;
	float d = length(at - ctr) - size * 0.5;
	float cov = (1.0 - smoothstep(-px, px, d)) * colour.a * mix(0.15, 1.0, on);
	float halo = exp(-max(d, 0.0) / (size * 0.3)) * 0.35 * on * colour.a * step(0.0, d);
	rgb = rgb * (1.0 - halo) + colour.rgb * halo;
	al = al + halo * (1.0 - al);
	rgb = rgb * (1.0 - cov) + colour.rgb * cov;
	al = al + cov * (1.0 - al);
	COLOR = vec4(rgb, al);
}
