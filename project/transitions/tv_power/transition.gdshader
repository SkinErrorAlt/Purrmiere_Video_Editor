shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float off_share : hint_range(0.2, 0.8) = 0.45;
uniform float glow : hint_range(0.0, 1.0) = 0.7;
uniform float dot_hold : hint_range(0.0, 0.6) = 0.2;
uniform vec4 tint : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform float curvature : hint_range(0.0, 1.0) = 0.35;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float tv_back(float t) {
	float c = 0.9;
	t = clamp(t, 0.0, 1.0) - 1.0;
	return 1.0 + (c + 1.0) * t * t * t + c * t * t;
}

vec4 tv_area(vec2 c, vec2 s, bool use_to) {
	vec2 fy = vec2(0.0, min(1.0 / (frame_px.y * max(s.y, 0.0001)), 1.0));
	vec2 fx = vec2(min(1.0 / (frame_px.x * max(s.x, 0.0001)), 1.0), 0.0);
	int ny = s.y < 0.5 ? 8 : 1;
	int nx = s.x < 0.5 ? 6 : 1;
	vec4 acc = vec4(0.0);
	for (int j = 0; j < 8; j++) {
		if (j >= ny) {
			break;
		}
		float oy = ny == 1 ? 0.0 : (float(j) + 0.5) / float(ny) - 0.5;
		for (int i = 0; i < 6; i++) {
			if (i >= nx) {
				break;
			}
			float ox = nx == 1 ? 0.0 : (float(i) + 0.5) / float(nx) - 0.5;
			vec2 q = clamp(c + fy * oy + fx * ox, vec2(0.0), vec2(1.0));
			acc += use_to ? texture(to_tex, q) : texture(from_tex, q);
		}
	}
	return acc / float(nx * ny);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 seq = frame_px / max(px_scale, 0.0001);
	float ratio = tr_ratio();
	float line_h = 3.0 / seq.y;
	float dot_w = 0.03 / ratio;
	float sx = 1.0;
	float sy = 1.0;
	float intensity = 1.0;
	float bloom = 0.0;
	bool use_to = p >= off_share;
	if (!use_to) {
		float u = p / off_share;
		float a_end = 0.68 * (1.0 - dot_hold);
		float b_end = 0.9 * (1.0 - dot_hold);
		float ta = clamp(u / a_end, 0.0, 1.0);
		float tb = clamp((u - a_end) / (b_end - a_end), 0.0, 1.0);
		float tc = clamp((u - b_end) / (1.0 - b_end), 0.0, 1.0);
		sy = mix(1.0, line_h, ta * ta * (3.0 - 2.0 * ta));
		sx = mix(1.0, 0.94, ta);
		sx = mix(sx, dot_w, tr_ease(tb, 3));
		float shrink = 1.0 - 0.6 * tc;
		sx *= shrink;
		sy *= mix(1.0, dot_w * ratio / max(line_h, 0.0001), tb) * shrink;
		intensity = 1.0 - tc * tc * (3.0 - 2.0 * tc);
	} else {
		float v = (p - off_share) / (1.0 - off_share);
		float ta = clamp(v / 0.06, 0.0, 1.0);
		float tb = clamp((v - 0.06) / 0.16, 0.0, 1.0);
		float tcv = clamp((v - 0.22) / 0.68, 0.0, 1.0);
		intensity = ta * ta * (3.0 - 2.0 * ta);
		float grow = 0.4 + 0.6 * ta;
		sx = mix(dot_w, 1.0, tr_ease(tb, 2)) * mix(grow, 1.0, tb);
		float dot_y = dot_w * ratio * grow;
		float rise = tcv * tcv * (3.0 - 2.0 * tcv) + 0.4 * sin(TR_PI * tcv) * tcv * tcv * tcv;
		sy = mix(mix(dot_y, line_h, tb), 1.0, rise);
		if (v >= 1.0) {
			sy = 1.0;
		}
		bloom = 1.0 - smoothstep(0.3, 1.0, v);
	}
	float edge = smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.9, 1.0, p));
	vec2 w = tr_world(uv);
	vec2 hs = vec2(sx * ratio, sy) * 0.5;
	float r = min(hs.x, hs.y) * smoothstep(0.25, 0.02, min(sx, sy)) + 0.05 * curvature * edge * min(sy, 1.0);
	r = min(r, min(hs.x, hs.y));
	vec2 dq = abs(w) - (hs - r);
	float sd = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0) - r;
	float cov = clamp(0.5 - sd * frame_px.y, 0.0, 1.0);
	vec2 q = w / max(hs, vec2(0.000001));
	float kb = curvature * 0.12 * edge;
	vec2 qs = q * (1.0 - kb * 1.5 * (1.0 - min(q.x * q.x, 1.0)) * (1.0 - min(q.y * q.y, 1.0)));
	vec2 src = vec2(0.5 + qs.x * 0.5, 0.5 - qs.y * 0.5);
	vec4 pic = tv_area(src, vec2(sx, sy), use_to);
	float gain = min(1.0 / max(sx * sy, 0.0001), 400.0);
	float whiten = clamp(1.0 - 1.0 / sqrt(gain), 0.0, 1.0);
	float lum = dot(pic.rgb, vec3(0.299, 0.587, 0.114));
	float energy = max(lum * gain, 1.4 * whiten * pic.a);
	vec3 hot = mix(pic.rgb * min(gain, 1.0 + 3.0 * whiten), tint.rgb * energy, whiten);
	hot += tint.rgb * bloom * glow * 0.35 * pic.a;
	vec4 screen = vec4(clamp(hot, vec3(0.0), vec3(1.0)) * intensity, pic.a * intensity);
	if (whiten > 0.0) {
		screen = vec4(min(screen.rgb, vec3(screen.a)), screen.a);
	}
	float out_d = max(sd, 0.0);
	float halo = glow * intensity * (whiten + bloom * 0.6) * (exp(-out_d / 0.01) * 0.9 + exp(-out_d / 0.06) * 0.35);
	halo = clamp(halo, 0.0, 1.0);
	vec4 plain = use_to ? to_at(uv) : from_at(uv);
	vec4 bgc = vec4(background.rgb * background.a, background.a) * edge;
	vec4 fill = mix(mix(plain, bgc, edge), bgc, cov);
	fill = vec4(tint.rgb * halo, halo) + fill * (1.0 - halo);
	return screen * cov + fill * (1.0 - cov * screen.a);
}

void fragment() {
	COLOR = transition(UV);
}
