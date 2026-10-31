shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float move_time : hint_range(0.05, 3.0) = 0.4;
uniform float flash : hint_range(0.0, 1.0) = 0.8;
uniform float size : hint_range(0.2, 1.0) = 0.72;
uniform float tilt : hint_range(-45.0, 45.0) = -5.0;
uniform vec2 photo_at = vec2(0.5, 0.47);
uniform int style : hint_range(0, 2) = 1;
uniform float border : hint_range(0.0, 120.0) = 22.0;
uniform vec4 paper_colour : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform int behind : hint_range(0, 1) = 0;
uniform float dim : hint_range(0.0, 1.0) = 0.45;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;

float box_sd(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

vec4 blurred(sampler2D tex, vec2 uv) {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 s = texture(tex, uv) * 4.0;
	s += texture(tex, uv + px * vec2(-1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, -1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, 1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(-1.0, -1.0));
	s += texture(tex, uv + px * vec2(1.0, -1.0));
	s += texture(tex, uv + px * vec2(-1.0, 1.0));
	s += texture(tex, uv + px * vec2(1.0, 1.0));
	return s / 16.0;
}

void fragment() {
	vec4 orig = texture(effect_tex, UV);
	float t = clip_time - starts_at;
	if (t < 0.0) {
		COLOR = orig;
	} else {
		vec2 sz = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
		float ps = max(px_scale * sz.x / max(tex_size.x, 1.0), 0.0001);
		float m = clamp(t / max(move_time, 0.01), 0.0, 1.0);
		float mm = m - 1.0;
		float me = 1.0 + 2.4 * mm * mm * mm + 1.4 * mm * mm;
		float sc = mix(1.0, clamp(size, 0.2, 1.0), me);
		float ang = radians(tilt) * me;
		vec2 ctr = mix(vec2(0.5), photo_at, me) * sz;
		vec2 d = UV * sz - ctr;
		float cs = cos(ang);
		float sn = sin(ang);
		vec2 l = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
		vec2 half_pic = 0.5 * sz * sc;
		float b = style == 2 ? 0.0 : max(border, 0.0) * ps * clamp(me, 0.0, 1.2);
		float extra = style == 1 ? b * 2.6 : 0.0;
		vec2 frame_half = half_pic + vec2(b, b + extra * 0.5);
		vec2 frame_off = vec2(0.0, extra * 0.5);
		float aa = max(ps, 0.5);
		float in_pic = clamp(0.5 - box_sd(l, half_pic) / aa, 0.0, 1.0);
		float in_frame = clamp(0.5 - box_sd(l - frame_off, frame_half) / aa, 0.0, 1.0);
		vec4 back = vec4(0.0);
		if (behind == 0) {
			vec4 bl = blurred(TEXTURE, UV);
			float k = 1.0 - clamp(dim, 0.0, 1.0) * clamp(me, 0.0, 1.0);
			back = vec4(bl.rgb * k, bl.a);
		}
		vec2 sh_off = vec2(6.0, 12.0) * ps * clamp(me, 0.0, 1.0);
		float soft = (6.0 + 22.0 * sc) * ps;
		float sd_sh = box_sd(l - frame_off - sh_off, frame_half);
		float sh = clamp(shadow, 0.0, 1.0) * 0.75 * (1.0 - smoothstep(-soft * 0.3, soft, sd_sh)) * clamp(me * 1.5, 0.0, 1.0);
		back = vec4(back.rgb * (1.0 - sh), back.a + sh * (1.0 - back.a));
		vec2 src = l / sc + 0.5 * sz;
		vec4 pic = texture(effect_tex, clamp(src / sz, vec2(0.0), vec2(1.0)));
		vec4 paper = vec4(paper_colour.rgb, 1.0);
		vec4 card = mix(paper * in_frame, pic, in_pic);
		float ca = card.a;
		vec4 o = card + back * (1.0 - ca);
		float f = clamp(flash, 0.0, 1.0) * exp(-t * 7.0);
		o = vec4(o.rgb + (vec3(o.a) - o.rgb) * f, o.a) + vec4(vec3(1.0), 1.0) * f * (1.0 - o.a);
		COLOR = vec4(clamp(o.rgb, vec3(0.0), vec3(clamp(o.a, 0.0, 1.0))), clamp(o.a, 0.0, 1.0));
	}
}
