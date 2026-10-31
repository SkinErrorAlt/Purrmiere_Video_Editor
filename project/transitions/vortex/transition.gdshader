shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int incoming = 0;
uniform vec2 centre = vec2(0.25, 0.5);
uniform float turns : hint_range(0.0, 3.0) = 1.0;
uniform int direction = 0;
uniform float pause : hint_range(-0.6, 0.5) = -0.5;
uniform float tile_size : hint_range(6.0, 120.0) = 28.0;
uniform float stagger : hint_range(0.0, 1.0) = 0.8;
uniform float depth : hint_range(0.0, 1.0) = 0.6;
uniform float tumble : hint_range(0.0, 2.0) = 1.0;
uniform float lens : hint_range(10.0, 90.0) = 45.0;
uniform float backdrop : hint_range(0.0, 1.0) = 0.45;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float reach_from(vec2 v) {
	return length(abs(v) + vec2(tr_ratio() * 0.5, 0.5));
}

float tile_life(vec2 c, float t, int layer, vec2 v) {
	float along = clamp(length(c - v) / reach_from(v), 0.0, 1.0);
	float n = tr_noise(c * 4.0 + vec2(7.0, 3.0));
	float spread = stagger * 0.6;
	float delay = spread * (along * 0.65 + n * 0.35) + float(layer) * stagger * 0.03;
	float span = 1.0 - spread - stagger * 0.06;
	return clamp((t - delay) / max(span, 0.05), 0.0, 1.0);
}

float swirl_angle(float s, float r0, float sgn) {
	return sgn * turns * 2.0 * TR_PI * pow(s, 1.3) * 0.5 / (r0 + 0.25);
}

float pull(float s) {
	return 1.0 - 0.94 * pow(s, 1.3);
}

float tilt_amount(float s) {
	return smoothstep(0.0, 0.35, s);
}

float tilt_angle() {
	return depth * 1.15;
}

float lift_z(float s) {
	return depth * (-0.25 * sin(TR_PI * min(s * 1.6, 1.0)) + 0.8 * s * s);
}

vec3 spiral_point(vec2 home, float s, vec2 v, float sgn) {
	float ang = swirl_angle(s, length(home - v), sgn);
	vec2 dd = tr_rotate(home - v, ang) * pull(s);
	float a = tilt_amount(s);
	float tt = tilt_angle();
	return vec3(v.x + dd.x, v.y + dd.y * (1.0 - a * (1.0 - cos(tt))), dd.y * a * sin(tt) + lift_z(s));
}

vec2 home_from_screen(vec2 q, float s, vec2 v, float sgn, float d) {
	float a = tilt_amount(s);
	float tt = tilt_angle();
	float ka = a * sin(tt);
	float kc = 1.0 - a * (1.0 - cos(tt));
	float b0 = lift_z(s);
	float dy = (q.y * (d + b0) - v.y * d) / max(kc * d - q.y * ka, 0.02);
	float z = dy * ka + b0;
	float dx = q.x * (d + z) / d - v.x;
	vec2 dd = vec2(dx, dy) / pull(s);
	return v + tr_rotate(dd, -swirl_angle(s, length(dd), sgn));
}

mat3 axis_turn(vec3 axis, float a) {
	vec3 k = normalize(axis);
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(
		vec3(t * k.x * k.x + c, t * k.x * k.y + s * k.z, t * k.x * k.z - s * k.y),
		vec3(t * k.x * k.y - s * k.z, t * k.y * k.y + c, t * k.y * k.z + s * k.x),
		vec3(t * k.x * k.z + s * k.y, t * k.y * k.z - s * k.x, t * k.z * k.z + c));
}

vec4 tiles(vec2 p, float t, bool use_from, vec2 v, float sgn, out float cov) {
	cov = 0.0;
	if (t <= 0.0) {
		vec2 uvr = tr_frame_uv(p);
		cov = tr_inside(uvr) ? 1.0 : 0.0;
		return (use_from ? from_at(uvr) : to_at(uvr)) * cov;
	}
	if (t >= 1.0) {
		return vec4(0.0);
	}
	float d = tr_camera_distance(lens);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(p, d));
	vec3 light = normalize(vec3(-0.4, 0.65, -0.65));
	float ts = max(tile_size * px_scale, 1.0) / max(frame_px.y, 1.0);
	float px_world = 1.0 / max(frame_px.y, 1.0);
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	vec4 top_c = vec4(0.0);
	float top_v = 0.0;
	float top_t = 1e9;
	vec4 und_c = vec4(0.0);
	float und_v = 0.0;
	float und_t = 1e9;
	for (int layer = 0; layer < 3; layer++) {
		float lo = 0.0;
		float hi = 1.0;
		for (int i = 0; i < 7; i++) {
			float mid = (lo + hi) * 0.5;
			if (tile_life(home_from_screen(p, mid, v, sgn, d), t, layer, v) > mid) {
				lo = mid;
			} else {
				hi = mid;
			}
		}
		vec2 hc = home_from_screen(p, (lo + hi) * 0.5, v, sgn, d) / ts;
		vec2 base = floor(hc);
		vec2 side = vec2(fract(hc.x) < 0.5 ? -1.0 : 1.0, fract(hc.y) < 0.5 ? -1.0 : 1.0);
		for (int dy = 0; dy <= 1; dy++) {
			for (int dx = 0; dx <= 1; dx++) {
				vec2 cell = base + vec2(float(dx), float(dy)) * side;
				if (int(floor(tr_hash(cell + vec2(11.0, 5.0)) * 3.0)) != layer) {
					continue;
				}
				vec2 cc = (cell + 0.5) * ts;
				float s = tile_life(cc, t, layer, v);
				if (s >= 0.999) {
					continue;
				}
				vec3 x = spiral_point(cc, s, v, sgn);
				float ang = swirl_angle(s, length(cc - v), sgn);
				vec3 rnd = vec3(tr_hash2(cell + vec2(3.0, 9.0)), tr_hash(cell + vec2(8.0, 2.0)));
				float roll = tumble * s * TR_PI * (0.6 + 1.4 * rnd.x);
				mat3 lay_down = axis_turn(vec3(1.0, 0.0, 0.0), -tilt_amount(s) * tilt_angle());
				mat3 rot = lay_down * axis_turn(vec3(cos(rnd.y * 6.283), sin(rnd.y * 6.283), (rnd.z - 0.5) * 0.4), roll) * axis_turn(vec3(0.0, 0.0, 1.0), ang);
				vec3 n = rot * vec3(0.0, 0.0, 1.0);
				float dn = dot(dir, n);
				if (abs(dn) < 1e-5) {
					continue;
				}
				float th = dot(x - cam, n) / dn;
				if (th <= 0.0 || (th >= top_t && th >= und_t)) {
					continue;
				}
				float scale = 1.0 - 0.7 * pow(s, 1.5);
				vec3 local = transpose(rot) * (cam + dir * th - x) / scale;
				vec2 home = cc + local.xy;
				vec2 in_frame = half_frame - abs(home);
				float edge = min(min(ts * 0.5 - abs(local.x), ts * 0.5 - abs(local.y)), min(in_frame.x, in_frame.y));
				float moving = smoothstep(0.0, 0.1, s);
				float px_local = px_world * (d + x.z) / d / max(scale * max(abs(dn), 0.05), 0.0001);
				float c = moving > 0.0 ? clamp(edge / (px_local * moving) + 0.5, 0.0, 1.0) : (edge >= 0.0 ? 1.0 : 0.0);
				if (c <= 0.0) {
					continue;
				}
				vec2 huv = tr_frame_uv(home);
				vec4 col = use_from ? from_at(huv) : to_at(huv);
				vec3 nf = dn > 0.0 ? -n : n;
				float diff = max(dot(nf, light), 0.0);
				float spec = pow(max(dot(nf, normalize(light - dir)), 0.0), 30.0);
				float lit = (dn > 0.0 ? 0.62 : 0.45) + 0.42 * diff;
				float far_dim = clamp(1.0 - 0.6 * x.z, 0.45, 1.15);
				col = tr_shade(col, mix(1.0, lit * far_dim, moving));
				col.rgb += vec3(spec * 0.35 * moving) * col.a;
				float cv = c * (1.0 - smoothstep(0.88, 1.0, s));
				if (th < top_t) {
					und_c = top_c;
					und_v = top_v;
					und_t = top_t;
					top_c = col;
					top_v = cv;
					top_t = th;
				} else {
					und_c = col;
					und_v = cv;
					und_t = th;
				}
			}
		}
	}
	cov = top_v + und_v * (1.0 - top_v);
	return top_c * top_v + und_c * und_v * (1.0 - top_v);
}

vec4 lay(vec4 weighted, float cov, vec4 under, float leak) {
	return weighted + under * (1.0 - cov + max(cov - weighted.a, 0.0) * leak);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 w = tr_world(uv);
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	vec2 v_out = tr_world(centre);
	float sgn = direction == 0 ? -1.0 : 1.0;
	float c_out;
	if (incoming == 1) {
		vec4 a = tiles(w, p, true, v_out, sgn, c_out);
		return lay(a, c_out, to_at(uv), leak);
	}
	float len = (1.0 - pause) * 0.5;
	float t_out = clamp(p / len, 0.0, 1.0);
	float q = clamp(p / 0.92, 0.0, 1.0);
	float t_in = 1.0 - clamp((q - (1.0 - len)) / len, 0.0, 1.0);
	vec2 v_in = incoming == 0 ? -v_out : v_out;
	float sgn_in = incoming == 0 ? -sgn : sgn;
	vec4 bg = vec4(background.rgb * background.a, background.a);
	float swap = smoothstep(0.3, 0.7, p);
	float near_out = 1.0 - smoothstep(0.0, 0.3, tile_life(w, t_out, 1, v_out));
	float near_in = 1.0 - smoothstep(0.0, 0.45, tile_life(w, t_in, 1, v_in));
	float bright = mix(backdrop, 1.0, mix(near_out, near_in, swap));
	vec4 behind = tr_shade(mix(from_at(uv), to_at(uv), swap), bright);
	behind = tr_over(behind, bg);
	float c_in;
	vec4 a = tiles(w, t_out, true, v_out, sgn, c_out);
	vec4 b = tiles(w, t_in, false, v_in, sgn_in, c_in);
	vec4 res = lay(a, c_out, behind, leak);
	return lay(b, c_in, res, leak);
}

void fragment() {
	COLOR = transition(UV);
}
