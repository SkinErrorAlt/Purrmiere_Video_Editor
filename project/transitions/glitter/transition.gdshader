shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int shape = 1;
uniform float size : hint_range(20.0, 300.0) = 110.0;
uniform int direction = 0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float glint : hint_range(0.0, 1.0) = 0.7;
uniform float lens : hint_range(10.0, 90.0) = 50.0;
uniform float lift : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int behind = 0;

const float WINDOW = 0.3;

vec4 tile_of(vec2 pix, float s) {
	if (shape == 1) {
		float a = (pix.x + pix.y) / s;
		float b = (pix.x - pix.y) / s;
		float ia = floor(a);
		float ib = floor(b);
		return vec4(s * (ia + ib + 1.0) * 0.5, s * (ia - ib) * 0.5, 2.0, 0.0);
	}
	float h = s * 0.8660254;
	float row = floor(pix.y / h);
	float shift = mod(row, 2.0) * s * 0.5;
	float xs = pix.x + shift;
	float yl = pix.y - row * h;
	float cx = (floor(xs / s) + 0.5) * s;
	if (abs(xs - cx) <= s * 0.5 * yl / h) {
		return vec4(cx - shift, row * h + h * 2.0 / 3.0, 0.0, row);
	}
	float dx = xs < cx ? cx - s * 0.5 : cx + s * 0.5;
	return vec4(dx - shift, row * h + h / 3.0, 1.0, row);
}

bool in_tile(vec2 q, vec4 tile, float s) {
	float e = 0.01;
	if (tile.z > 1.5) {
		vec2 d = abs(q - tile.xy);
		return d.x + d.y <= s * 0.5 + e;
	}
	float h = s * 0.8660254;
	float dy = q.y - tile.w * h;
	if (dy < -e || dy > h + e) {
		return false;
	}
	float dx = abs(q.x - tile.x);
	float k = tile.z < 0.5 ? dy / h : 1.0 - dy / h;
	return dx <= s * 0.5 * k + e;
}

float tile_turn(vec4 tile) {
	vec2 cuv = clamp(tile.xy / frame_px, 0.0, 1.0);
	float pos = cuv.x * 0.8 + cuv.y * 0.2;
	if (direction == 1) {
		pos = (1.0 - cuv.x) * 0.8 + cuv.y * 0.2;
	} else if (direction == 2) {
		pos = cuv.y * 0.8 + cuv.x * 0.2;
	} else if (direction == 3) {
		pos = (1.0 - cuv.y) * 0.8 + cuv.x * 0.2;
	}
	float r = tr_hash(tile.xy * 0.013 + tile.z);
	float start = (pos * 0.8 + r * 0.2) * (1.0 - WINDOW);
	return clamp((progress - start) / WINDOW, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
	float s = max(size * px_scale, 4.0);
	float h = shape == 1 ? s * 0.5 : s * 0.8660254;
	vec2 pix = uv * frame_px;
	float d = tr_camera_distance(lens);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec2 sw = tr_world(uv);
	vec3 dir = normalize(vec3(sw, 0.0) - cam);
	bool about_x = shape == 1 && direction >= 2;
	float sgn = (direction == 1 || direction == 3) ? 1.0 : -1.0;
	float s_world = s / max(frame_px.y, 1.0);
	float best = 1e9;
	vec4 win_tile = vec4(0.0);
	float win_tk = 0.0;
	float win_theta = 0.0;
	vec2 win_src = vec2(0.0);
	bool win_front = true;
	vec3 win_n = vec3(0.0, 0.0, -1.0);
	vec3 win_hit = vec3(0.0);
	vec2 win_lp = vec2(0.0);
	for (int c = 0; c < 9; c++) {
		vec2 probe = pix + vec2(float(c % 3 - 1) * s * 0.5, float(c / 3 - 1) * h * 0.7);
		vec4 tile = tile_of(probe, s);
		float tk = tile_turn(tile);
		float theta = TR_PI * smoothstep(0.0, 1.0, tk);
		float deg = degrees(theta) * sgn;
		vec3 rot = about_x ? vec3(deg, 0.0, 0.0) : vec3(0.0, deg, 0.0);
		mat3 r = tr_rotation(rot);
		mat3 ri = transpose(r);
		vec2 cw = tr_world(tile.xy / frame_px);
		vec3 pivot = vec3(cw, -lift * s_world * 1.5 * sin(theta));
		vec3 o = ri * (cam - pivot);
		vec3 dl = ri * dir;
		if (abs(dl.z) < 0.000001) {
			continue;
		}
		float t = -o.z / dl.z;
		if (t <= 0.0 || t >= best) {
			continue;
		}
		vec3 hl = o + dl * t;
		vec2 shape_pix = tr_frame_uv(cw + hl.xy) * frame_px;
		if (!in_tile(shape_pix, tile, s)) {
			continue;
		}
		bool front = dl.z > 0.0;
		vec2 lp = hl.xy;
		if (!front) {
			if (about_x) {
				lp.y = -lp.y;
			} else {
				lp.x = -lp.x;
			}
		}
		best = t;
		win_tile = tile;
		win_tk = tk;
		win_theta = theta;
		win_src = tr_frame_uv(cw + lp);
		win_front = front;
		vec3 n = r * vec3(0.0, 0.0, -1.0);
		win_n = front ? n : -n;
		win_hit = cam + dir * t;
		win_lp = hl.xy / max(s_world * 0.5, 0.000001);
	}
	vec4 bg = vec4(background.rgb * background.a, background.a);
	if (best > 1e8) {
		return behind == 0 ? tr_shade(to_at(uv), 0.7) : bg;
	}
	vec4 c = win_front ? from_clamped(win_src) : to_clamped(win_src);
	if (win_tk <= 0.0) {
		return from_at(uv);
	} else if (win_tk >= 1.0) {
		return to_at(uv);
	}
	vec3 light = normalize(vec3(-0.45, 0.55, -1.0));
	float lam0 = dot(vec3(0.0, 0.0, -1.0), light);
	float lam = max(dot(win_n, light), 0.0) / lam0;
	float diffuse = mix(1.0, min(lam, 1.25), shading);
	vec3 view = normalize(cam - win_hit);
	vec3 half_v = normalize(light + view);
	float facing = pow(max(dot(win_n, half_v), 0.0), 6.0);
	float turning = smoothstep(0.0, 0.3, sin(win_theta));
	float across = about_x ? win_lp.y : win_lp.x;
	float centre = mix(-1.4, 1.4, win_theta / TR_PI) * (sgn > 0.0 ? 1.0 : -1.0);
	float band = exp(-pow((across - centre) / 0.16, 2.0));
	float g = glint * band * (0.35 + 0.65 * facing) * turning;
	vec3 rgb = c.rgb * diffuse * (1.0 - 0.35 * g) + vec3(0.88, 0.92, 1.0) * 1.1 * g * c.a;
	return vec4(min(rgb, vec3(c.a)), c.a);
}

void fragment() {
	COLOR = transition(UV);
}
