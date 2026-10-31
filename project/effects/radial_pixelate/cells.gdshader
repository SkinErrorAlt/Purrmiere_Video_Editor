shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D avg_tex : filter_linear, repeat_disable;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float ring_width : hint_range(2.0, 400.0) = 48.0;
uniform int wedges : hint_range(3, 256) = 32;
uniform int colour_from : hint_range(0, 1) = 1;
uniform float gap : hint_range(0.0, 20.0) = 0.0;
uniform vec4 gap_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float px_scale = 1.0;

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

vec4 sample_at(vec2 C, float r, float th, vec2 S, bool avg) {
	vec2 uv = mirror_uv((C + r * vec2(cos(th), sin(th))) / S);
	return avg ? textureLod(avg_tex, uv, 0.0) : textureLod(effect_tex, uv, 0.0);
}

vec3 cell_colour(float i, float j, vec2 C, vec2 S, float w, float dt) {
	vec4 acc = vec4(0.0);
	if (colour_from == 0) {
		acc = i < 0.5 ? sample_at(C, 0.0, 0.0, S, false) : sample_at(C, (i + 0.5) * w, (j + 0.5) * dt, S, false);
	} else if (i < 0.5) {
		acc = sample_at(C, 0.0, 0.0, S, true) * 2.0;
		for (int k = 0; k < 3; k++) {
			float r = w * (0.3 + 0.3 * float(k));
			for (int m = 0; m < 8; m++) {
				acc += sample_at(C, r, (float(m) + 0.5 * float(k)) * TAU / 8.0, S, true);
			}
		}
	} else {
		float arc = (i + 0.5) * w * dt;
		int na = clamp(int(arc / 16.0), 4, 16);
		for (int k = 0; k < 3; k++) {
			float r = (i + 0.2 + 0.3 * float(k)) * w;
			for (int m = 0; m < 16; m++) {
				if (m >= na) {
					break;
				}
				acc += sample_at(C, r, (j + (float(m) + 0.5) / float(na)) * dt, S, true);
			}
		}
	}
	return acc.a > 0.0001 ? clamp(acc.rgb / acc.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * 8.0, 0.0001);
	vec2 S = full / ps;
	vec2 C = centre * S;
	vec2 d = UV * S - C;
	float r = length(d);
	float w = max(ring_width, 0.5);
	float n = float(max(wedges, 1));
	float dt = TAU / n;
	float th = mod(atan(d.y, d.x), TAU);
	float i = floor(r / w);
	float j = min(floor(th / dt), n - 1.0);
	vec3 col = cell_colour(i, j, C, S, w, dt);
	float r_in = i < 0.5 ? 1e9 : (r - i * w) * ps;
	float r_out = ((i + 1.0) * w - r) * ps;
	float a_lo = i < 0.5 ? 1e9 : (th - j * dt) * r * ps;
	float a_hi = i < 0.5 ? 1e9 : ((j + 1.0) * dt - th) * r * ps;
	float dmin = min(min(r_in, r_out), min(a_lo, a_hi));
	if (dmin < 0.5) {
		float ni = i;
		float nj = j;
		if (r_in == dmin) {
			ni = i - 1.0;
		} else if (r_out == dmin) {
			ni = i + 1.0;
		} else if (a_lo == dmin) {
			nj = mod(j - 1.0 + n, n);
		} else {
			nj = mod(j + 1.0, n);
		}
		if (ni > 0.5 && i < 0.5) {
			nj = j;
		}
		vec3 nc = cell_colour(ni, nj, C, S, w, dt);
		col = mix(col, nc, clamp(0.5 - dmin, 0.0, 0.5));
	}
	if (gap > 0.0) {
		float gh = gap * ps * 0.5;
		float gm = (1.0 - smoothstep(gh - 0.5, gh + 0.5, dmin)) * min(1.0, gap * ps);
		col = mix(col, gap_colour.rgb, gm * gap_colour.a);
	}
	float a = textureLod(effect_tex, UV, 0.0).a;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
