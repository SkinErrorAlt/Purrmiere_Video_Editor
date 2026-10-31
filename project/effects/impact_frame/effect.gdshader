shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.02, 10.0) = 0.35;
uniform int style : hint_range(0, 2) = 0;
uniform float flips : hint_range(0.0, 30.0) = 12.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.0, 0.5) = 0.04;
uniform float flash : hint_range(0.0, 1.0) = 0.8;
uniform float lines : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 ink_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float needles(vec2 d, float reach, float ps, vec2 sk) {
	float r = length(d);
	float ang = r > 0.001 ? atan(d.y, d.x) : 0.0;
	float n = 110.0;
	float x = (ang / 6.2831853 + 0.5) * n;
	float k0 = floor(x);
	float amt = clamp(lines, 0.0, 1.0);
	float cov = 0.0;
	for (int j = -1; j <= 1; j++) {
		float k = k0 + float(j);
		vec4 h = hash42(vec2(mod(k, n), 5.0) + sk);
		if (h.w > amt) {
			continue;
		}
		float ca = k + 0.5 + (h.x - 0.5) * 0.8;
		float dang = (x - ca) / n * 6.2831853;
		float r0 = reach * (0.28 + 0.45 * h.y) * (1.15 - 0.5 * amt);
		if (r <= r0) {
			continue;
		}
		float grow = clamp((r - r0) / max(reach * 0.5, 1.0), 0.0, 1.0);
		float hw = ps * (1.0 + 7.0 * h.z * h.z) * sqrt(grow);
		float line = 1.0 - smoothstep(hw - 0.6, hw + 0.6, abs(dang) * r);
		cov = max(cov, line * clamp(hw * 2.0, 0.0, 1.0));
	}
	return cov;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dt = clip_time - starts_at;
	float dur = max(duration, 0.001);
	if (dt < 0.0 || dt > dur) {
		COLOR = c;
	} else {
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec2 size = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float flip = flips > 0.0 ? mod(floor(dt * flips), 2.0) : 0.0;
		float frame = flips > 0.0 ? floor(dt * flips) : 0.0;
		vec2 sk = vec2(mod(float(seed), 997.0) * 1.19 + 3.0, mod(frame, 512.0) * 2.31 + 1.0);
		vec2 cpx = centre * size;
		float reach = length(max(cpx, size - cpx));
		float lc = needles(UV * size - cpx, reach, ps, sk);
		vec3 outc;
		if (style == 2) {
			vec3 hard = clamp((rgb - 0.5) * 1.7 + 0.5, 0.0, 1.0);
			outc = flip > 0.5 ? hard : 1.0 - hard;
			outc = mix(outc, flip > 0.5 ? vec3(0.0) : vec3(1.0), lc);
		} else {
			float l = dot(rgb, LUMA);
			float s = max(softness, 0.0005);
			float p = smoothstep(threshold - s, threshold + s, l);
			if (style == 1) {
				p = 1.0 - p;
			}
			float line_value = style == 1 ? 1.0 : 0.0;
			if (flip > 0.5) {
				p = 1.0 - p;
				line_value = 1.0 - line_value;
			}
			p = mix(p, line_value, lc);
			outc = mix(ink_colour.rgb, paper_colour.rgb, p);
		}
		float fw = clamp(flash, 0.0, 1.0) * (1.0 - smoothstep(0.0, min(0.07, dur), dt));
		outc = mix(outc, paper_colour.rgb, fw);
		COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
	}
}
