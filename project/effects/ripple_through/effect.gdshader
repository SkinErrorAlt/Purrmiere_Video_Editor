shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.8;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style : hint_range(0, 1) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform float rings : hint_range(2.0, 40.0) = 12.0;
uniform float speed : hint_range(0.0, 4.0) = 1.5;
uniform float shine : hint_range(0.0, 1.0) = 0.4;
uniform float glow : hint_range(0.0, 1.0) = 0.25;

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

vec2 mirror_uv(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		vec2 asp = vec2(sz.x / sz.y, 1.0);
		float e = g * g * (3.0 - 2.0 * g);
		float amp = clamp(amount, 0.0, 1.0) * e;
		float tt = clip_time * clamp(speed, 0.0, 4.0);
		float wn = clamp(rings, 2.0, 40.0);
		vec2 uv = UV;
		float slope = 0.0;
		if (style == 0) {
			vec2 ctr = clamp(centre, vec2(-0.5), vec2(1.5));
			vec2 rel = (UV - ctr) * asp;
			float r = length(rel);
			float front = is_in ? 2.4 : mix(0.15, 2.4, sqrt(g));
			float env = smoothstep(front, front - 0.35, r) * (0.35 + 0.65 * exp(-r * 1.2));
			float ph = r * wn * 6.2831853 - tt * 6.2831853;
			float disp = amp * 0.035 * env * sin(ph);
			slope = amp * env * cos(ph);
			vec2 dir = r > 0.00001 ? rel / r : vec2(0.0);
			uv = ctr + (rel + dir * disp) / asp;
		} else {
			float ph = UV.y * wn * 3.1415926 + tt * 6.2831853;
			float disp = amp * 0.045 * sin(ph) * (0.6 + 0.4 * sin(UV.y * 5.0 - tt * 2.0));
			slope = amp * cos(ph);
			uv = vec2(UV.x + disp, UV.y + amp * 0.01 * sin(UV.x * 9.0 + tt * 3.0));
		}
		vec4 p = texture(TEXTURE, mirror_uv(uv));
		float a = p.a;
		vec3 rgb = a > 0.0001 ? p.rgb / a : vec3(0.0);
		rgb += vec3(clamp(shine, 0.0, 1.0) * 0.35 * slope);
		float gl = clamp(glow, 0.0, 1.0) * e;
		if (gl > 0.001) {
			vec2 px = 1.0 / sz * (4.0 + 10.0 * e) * sz.y / 540.0;
			vec4 s = vec4(0.0);
			for (int i = 0; i < 8; i++) {
				float an = float(i) * 0.7853982 + 0.3;
				s += texture(TEXTURE, mirror_uv(uv + vec2(cos(an), sin(an)) * px * 2.0));
			}
			s /= 8.0;
			vec3 soft = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			vec3 bright = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * (1.0 - clamp(soft * 0.8, 0.0, 1.0));
			rgb = mix(rgb, bright, gl);
		}
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
