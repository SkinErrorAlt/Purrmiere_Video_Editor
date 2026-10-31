shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int strokes : hint_range(1, 8) = 3;
uniform int order = 0;
uniform int orientation = 0;
uniform float overlap : hint_range(0.0, 0.6) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float dryness : hint_range(0.0, 1.0) = 0.5;
uniform float wobble : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.0, 0.1) = 0.003;
uniform int curve = 0;

int band_of(int seq, int count) {
	if (order == 1) {
		return count - 1 - seq;
	} else if (order == 2) {
		int half_seq = seq / 2;
		return seq % 2 == 0 ? half_seq : count - 1 - half_seq;
	}
	return seq;
}

vec4 transition(vec2 uv) {
	int count = clamp(strokes, 1, 8);
	float n = float(count);
	float along = orientation == 0 ? uv.x : uv.y;
	float across = orientation == 0 ? uv.y : uv.x;
	float len_along = orientation == 0 ? frame_px.x : frame_px.y;
	float len_across = orientation == 0 ? frame_px.y : frame_px.x;
	float aspect = len_along / max(len_across, 1.0);
	float rough = clamp(roughness, 0.0, 1.0);
	float dry = clamp(dryness, 0.0, 1.0);
	float ov = clamp(overlap, 0.0, 0.6);
	float dur = 1.0 / ((n - 1.0) * (1.0 - ov) + 1.0);
	float pg = tr_ease(progress, curve == 1 ? 3 : 0);
	float lag_max = 0.03 + 0.09 * rough;
	float tip = 0.04 * (0.3 + rough);
	float dry_len = 0.04 + 0.14 * dry;
	float s = max(softness, 1.0 / len_along);
	float sv = 1.5 / len_across;
	float hb = 0.5 / n;
	float wob_amp = clamp(wobble, 0.0, 1.0) * hb * 0.35;
	float world_across = across * len_across / max(frame_px.y, 1.0);
	float b1 = tr_noise(vec2(world_across * 260.0, 3.7));
	float b2 = tr_noise(vec2(world_across * 90.0, 8.1));
	float b3 = tr_noise(vec2(world_across * 25.0, 1.9));
	float bristle = clamp(0.4 * b1 + 0.35 * b2 + 0.25 * b3, 0.0, 1.0);
	bristle = smoothstep(0.15, 0.85, bristle);
	float total = 1.0 + 2.0 * s;
	float cover = 0.0;
	for (int seq = 0; seq < 8; seq++) {
		if (seq >= count) {
			break;
		}
		int band = band_of(seq, count);
		float fb = float(band);
		float start = float(seq) * dur * (1.0 - ov);
		float local = clamp((pg - start) / dur, 0.0, 1.0);
		float xs = seq % 2 == 0 ? along : 1.0 - along;
		float yc = (fb + 0.5) / n + wob_amp * (sin(xs * 5.3 + fb * 2.1) * 0.6 + (tr_noise(vec2(xs * 3.0, fb * 4.7)) - 0.5) * 0.8);
		float dy = abs(across - yc);
		float edge_n = tr_noise(vec2(xs * 14.0 + fb * 5.1, across > yc ? 2.3 : 7.9)) * 0.7 + tr_noise(vec2(xs * 60.0, fb + 11.0)) * 0.3;
		float h = hb + sv + wob_amp + hb * (0.1 + 0.45 * rough) * edge_n;
		float cy = 1.0 - smoothstep(h - sv, h, dy);
		float rel = clamp(dy / h, 0.0, 1.0);
		float head = sqrt(max(1.0 - local, 0.0));
		float lag = lag_max * bristle * head;
		float front = local * total - lag - tip * rel * rel * head;
		float taper = s + (0.35 * lag + 0.01 * rough) * head;
		float cx = 1.0 - smoothstep(front - taper, front, xs);
		float behind = front - xs;
		float dl = dry_len * head;
		float zone = dl > 0.000001 ? clamp(behind / dl, 0.0, 1.0) : 1.0;
		float streak = tr_noise(vec2(xs * aspect * 9.0 + fb * 3.3, world_across * 140.0));
		float speck = tr_noise(vec2(xs * aspect * 60.0, world_across * 420.0));
		float paint = 0.6 * streak + 0.4 * speck;
		float th = (1.0 - zone) * 0.75 * dry;
		float dry_cov = smoothstep(th - 0.12, th + 0.02, paint + zone * 0.2);
		dry_cov = mix(1.0, dry_cov, step(0.0001, th));
		cover = max(cover, cx * cy * dry_cov);
	}
	return mix(from_at(uv), to_at(uv), cover);
}

void fragment() {
	COLOR = transition(UV);
}
