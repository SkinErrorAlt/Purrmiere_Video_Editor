shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.4;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float bounce : hint_range(0.0, 1.0) = 0.6;
uniform float squash : hint_range(0.0, 1.0) = 0.4;
uniform float spin : hint_range(-720.0, 720.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.3;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float pop_curve(float u, float k) {
	float r = 1.0 - clamp(u, 0.0, 1.0);
	return 1.0 - r * r * r * cos(k * 3.1415926 * clamp(u, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float u = 1.0 - g;
		float k = 1.0 + 2.5 * clamp(bounce, 0.0, 1.0);
		float e = pop_curve(u, k);
		float v = (pop_curve(u + 0.03, k) - pop_curve(u - 0.03, k)) / 0.06;
		float sq = clamp(squash, 0.0, 1.0) * 0.12 * clamp(v, -3.0, 3.0);
		vec2 sc = vec2(e * (1.0 - sq), e * (1.0 + sq));
		vec4 o = vec4(0.0);
		if (sc.x > 0.002 && sc.y > 0.002) {
			vec2 cp = clamp(centre, vec2(0.0), vec2(1.0)) * sz;
			vec2 d = UV * sz - cp;
			float ang = -radians(spin) * (1.0 - e);
			float cs = cos(ang);
			float sn = sin(ang);
			d = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
			vec2 src = cp + d / sc;
			vec2 edge = min(src, sz - src) * min(sc.x, sc.y);
			float m = clamp(min(edge.x, edge.y) / max(ps, 0.5) + 0.5, 0.0, 1.0);
			if (m > 0.0) {
				o = texture(TEXTURE, clamp(src / sz, vec2(0.0), vec2(1.0))) * m;
			}
			float fa = mix(1.0, clamp(e * 1.6, 0.0, 1.0), clamp(fade, 0.0, 1.0));
			o *= fa;
		}
		COLOR = o;
	}
}
