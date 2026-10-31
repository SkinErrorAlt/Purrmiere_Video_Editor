shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.7;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int dots : hint_range(4, 60) = 16;
uniform int order : hint_range(0, 2) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float spread : hint_range(0.0, 0.9) = 0.6;
uniform int shape : hint_range(0, 1) = 0;
uniform float rim : hint_range(0.0, 20.0) = 0.0;
uniform vec4 rim_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;

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

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float order_of(vec2 cc, float asp) {
	if (order == 0) {
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		float ext = abs(dir.x) * asp * 0.5 + abs(dir.y) * 0.5;
		return clamp(dot(cc - vec2(asp, 1.0) * 0.5, dir) / max(ext, 0.0001) * 0.5 + 0.5, 0.0, 1.0);
	}
	if (order == 1) {
		vec2 ctr = clamp(centre, vec2(0.0), vec2(1.0)) * vec2(asp, 1.0);
		float far_d = 0.0;
		far_d = max(far_d, length(ctr));
		far_d = max(far_d, length(ctr - vec2(asp, 0.0)));
		far_d = max(far_d, length(ctr - vec2(0.0, 1.0)));
		far_d = max(far_d, length(ctr - vec2(asp, 1.0)));
		return clamp(length(cc - ctr) / max(far_d, 0.0001), 0.0, 1.0);
	}
	return hash12(floor(cc * 997.0) + vec2(float(seed) * 5.3, 1.7));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		float px = 1.0 / sz.y;
		float cs = asp / float(clamp(dots, 4, 60));
		vec2 x = UV * vec2(asp, 1.0);
		vec2 offs = vec2(asp, 1.0) * 0.5;
		vec2 home = floor((x - offs) / cs + 0.5);
		float sp = clamp(spread, 0.0, 0.9);
		float full_r = shape == 1 ? cs * 1.02 : cs * 0.72;
		float inside = 0.0;
		float rim_m = 0.0;
		float rw = max(rim, 0.0) * max(px_scale, 0.0001) * px;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = home + vec2(float(i), float(j));
				vec2 cc = cell * cs + offs;
				float o = order_of(cc, asp);
				float oo = is_in ? 1.0 - o : o;
				float l = clamp((g - oo * sp) / max(1.0 - sp, 0.0001), 0.0, 1.0);
				l = l * l * (3.0 - 2.0 * l);
				float r = is_in ? (1.0 - l) * full_r : l * full_r;
				vec2 dv = x - cc;
				float dist = shape == 1 ? (abs(dv.x) + abs(dv.y)) * 0.7071 : length(dv);
				float rr = shape == 1 ? r * 0.7071 : r;
				float m = r <= 0.0 ? 0.0 : clamp((rr - dist) / px + 0.5, 0.0, 1.0);
				inside = max(inside, m);
				if (rw > 0.0 && r > 0.0) {
					rim_m = max(rim_m, clamp((rr + rw - dist) / px + 0.5, 0.0, 1.0) * (1.0 - m));
				}
			}
		}
		float keep = is_in ? inside : 1.0 - inside;
		vec4 o_col = c * keep;
		if (rw > 0.0) {
			float ra = clamp(rim_m * (1.0 - inside), 0.0, 1.0) * clamp(rim_colour.a, 0.0, 1.0);
			o_col = vec4(rim_colour.rgb * ra, ra) + o_col * (1.0 - ra);
		}
		COLOR = o_col;
	}
}
