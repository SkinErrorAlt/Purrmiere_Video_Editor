shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 canvas_px = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int part = 0;
uniform int fit = 0;
uniform vec2 focus = vec2(0.5, 0.5);
uniform float zoom : hint_range(1.0, 4.0) = 1.0;
uniform float gap : hint_range(0.0, 0.06) = 0.006;
uniform bool outer = false;
uniform vec4 gap_colour : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float roundness : hint_range(0.0, 0.5) = 0.0;
uniform int animate = 0;
uniform float anim_time : hint_range(0.05, 2.0) = 0.45;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float ease_out(float x) {
	float v = 1.0 - clamp(x, 0.0, 1.0);
	return 1.0 - v * v * v;
}

vec4 cell_of(int i) {
	float t = 1.0 / 3.0;
	if (i == 1) { return vec4(0.5, 0.0, 0.5, 1.0); }
	if (i == 2) { return vec4(0.0, 0.0, 1.0, 0.5); }
	if (i == 3) { return vec4(0.0, 0.5, 1.0, 0.5); }
	if (i == 4) { return vec4(0.0, 0.0, t, 1.0); }
	if (i == 5) { return vec4(t, 0.0, t, 1.0); }
	if (i == 6) { return vec4(2.0 * t, 0.0, t, 1.0); }
	if (i == 7) { return vec4(0.0, 0.0, 1.0, t); }
	if (i == 8) { return vec4(0.0, t, 1.0, t); }
	if (i == 9) { return vec4(0.0, 2.0 * t, 1.0, t); }
	if (i == 10) { return vec4(0.0, 0.0, 0.5, 0.5); }
	if (i == 11) { return vec4(0.5, 0.0, 0.5, 0.5); }
	if (i == 12) { return vec4(0.0, 0.5, 0.5, 0.5); }
	if (i == 13) { return vec4(0.5, 0.5, 0.5, 0.5); }
	return vec4(0.0, 0.0, 0.5, 1.0);
}

void fragment() {
	float asp = canvas_px.x / max(canvas_px.y, 1.0);
	vec4 cell = cell_of(part);
	vec2 lo = cell.xy * vec2(asp, 1.0);
	vec2 hi = (cell.xy + cell.zw) * vec2(asp, 1.0);
	vec2 cell_lo = lo;
	vec2 cell_hi = hi;
	float g = clamp(gap, 0.0, 0.06) * 0.5;
	vec2 edge_lo = vec2(cell.x < 0.001 ? (outer ? g * 2.0 : 0.0) : g, cell.y < 0.001 ? (outer ? g * 2.0 : 0.0) : g);
	vec2 edge_hi = vec2(cell.x + cell.z > 0.999 ? (outer ? g * 2.0 : 0.0) : g, cell.y + cell.w > 0.999 ? (outer ? g * 2.0 : 0.0) : g);
	lo += edge_lo;
	hi -= edge_hi;
	vec2 in_size = max(hi - lo, vec2(0.0005));
	vec2 shift = vec2(0.0);
	if (animate > 0) {
		float at = max(anim_time, 0.01);
		float t_left = animate == 2 ? clip_duration - clip_time : 1000000.0;
		float k = ease_out(clamp(min(clip_time, t_left) / at, 0.0, 1.0));
		vec2 mid = (cell_lo + cell_hi) * 0.5;
		vec2 away = mid - vec2(asp * 0.5, 0.5);
		vec2 dir = abs(away.x) * cell.w >= abs(away.y) * cell.z * asp ? vec2(sign(away.x + 0.00001), 0.0) : vec2(0.0, sign(away.y + 0.00001));
		if (length(away) < 0.001) {
			dir = vec2(0.0, 1.0);
		}
		shift = dir * (abs(dir.x) * (cell_hi.x - cell_lo.x) + abs(dir.y) * (cell_hi.y - cell_lo.y) + 0.02) * (1.0 - k);
	}
	vec2 q = UV * vec2(asp, 1.0) - shift;
	float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
	vec2 cc = (cell_lo + cell_hi) * 0.5;
	vec2 ch = (cell_hi - cell_lo) * 0.5;
	float cell_d = box_sd(q - cc, ch, 0.0);
	float cell_cov = clamp(0.5 - cell_d / aa, 0.0, 1.0);
	vec2 ic = (lo + hi) * 0.5;
	vec2 ih = in_size * 0.5;
	float rad = clamp(roundness, 0.0, 0.5) * 2.0 * min(ih.x, ih.y);
	float d = box_sd(q - ic, ih, rad);
	float cov = clamp(0.5 - d / aa, 0.0, 1.0);
	vec2 sb = max(source_box.zw, vec2(0.0001));
	float own = sb.x * asp / sb.y;
	float want = in_size.x / in_size.y;
	vec2 local = (q - lo) / in_size;
	vec4 pic = vec4(0.0);
	if (fit == 1) {
		vec2 shown = want > own ? vec2(own / want, 1.0) : vec2(1.0, want / own);
		vec2 f = (local - (vec2(1.0) - shown) * 0.5) / shown;
		vec2 inside = step(vec2(0.0), f) * step(f, vec2(1.0));
		pic = texture(effect_tex, clamp(f, vec2(0.0), vec2(1.0))) * inside.x * inside.y;
	} else {
		vec2 crop = want < own ? vec2(want / own, 1.0) : vec2(1.0, own / want);
		crop /= max(zoom, 1.0);
		vec2 c0 = clamp(focus - crop * 0.5, vec2(0.0), vec2(1.0) - crop);
		pic = texture(effect_tex, c0 + clamp(local, vec2(0.0), vec2(1.0)) * crop);
	}
	vec4 back = vec4(gap_colour.rgb, 1.0) * gap_colour.a;
	vec4 inner = pic + back * (1.0 - pic.a);
	COLOR = mix(back * cell_cov, inner, cov);
}
