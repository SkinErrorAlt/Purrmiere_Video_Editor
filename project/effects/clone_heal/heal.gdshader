shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 target_centre = vec2(0.6, 0.5);
uniform float width : hint_range(0.01, 1.0) = 0.12;
uniform float height : hint_range(0.01, 1.0) = 0.16;
uniform vec2 source_centre = vec2(0.42, 0.5);
uniform int shape = 0;
uniform float feather : hint_range(0.0, 0.1) = 0.015;
uniform float heal : hint_range(0.0, 1.0) = 1.0;
uniform int mirror = 0;

const int RIM = 48;
const float TWO_PI = 6.28318530718;

vec2 rim_point(int i, vec2 c, vec2 hb, float grow) {
	float t = (float(i) + 0.5) / float(RIM);
	vec2 h = hb + vec2(grow);
	if (shape == 0) {
		float a = t * TWO_PI;
		return c + vec2(cos(a), sin(a)) * h;
	}
	float per = 4.0 * (h.x + h.y);
	float d = t * per;
	if (d < 2.0 * h.x) {
		return c + vec2(-h.x + d, -h.y);
	}
	d -= 2.0 * h.x;
	if (d < 2.0 * h.y) {
		return c + vec2(h.x, -h.y + d);
	}
	d -= 2.0 * h.y;
	if (d < 2.0 * h.x) {
		return c + vec2(h.x - d, h.y);
	}
	d -= 2.0 * h.x;
	return c + vec2(-h.x, h.y - d);
}

float region_sdf(vec2 p, vec2 c, vec2 hb) {
	vec2 q = p - c;
	if (shape == 0) {
		float k = length(q / hb);
		return (k - 1.0) * min(hb.x, hb.y);
	}
	vec2 e = abs(q) - hb;
	return length(max(e, vec2(0.0))) + min(max(e.x, e.y), 0.0);
}

vec2 mirrored(vec2 off) {
	if (mirror == 1) {
		return vec2(-off.x, off.y);
	}
	if (mirror == 2) {
		return vec2(off.x, -off.y);
	}
	return off;
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float asp = full.x / max(full.y, 1.0);
	vec2 sc = vec2(asp, 1.0);
	vec2 p = UV * sc;
	vec2 tc = target_centre * sc;
	vec2 hb = vec2(width * asp, height) * 0.5;
	float f = max(feather, 0.0008);
	float d = region_sdf(p, tc, hb);
	float m = 1.0 - smoothstep(-f, 0.0, d);
	if (m <= 0.0) {
		COLOR = c;
	} else {
		vec2 shift = (source_centre - target_centre) * sc;
		vec2 off = mirrored(p - tc);
		vec2 sp = tc + shift + off;
		vec4 s = texture(effect_tex, sp / sc);
		vec4 corr = vec4(0.0);
		if (heal > 0.0) {
			float wsum = 0.0;
			float grow = f + 3.0 / full.y;
			for (int i = 0; i < RIM; i++) {
				vec2 b = rim_point(i, tc, hb, grow);
				vec2 bs = tc + shift + mirrored(b - tc);
				vec4 dt = texture(TEXTURE, b / sc) - texture(TEXTURE, bs / sc);
				vec2 dv = (p - b) * full.y;
				float w = 1.0 / max(dot(dv, dv), 0.25);
				corr += dt * w;
				wsum += w;
			}
			corr = corr / max(wsum, 0.000001) * clamp(heal, 0.0, 1.0);
		}
		vec4 patched = clamp(s + corr, vec4(0.0), vec4(1.0));
		patched.rgb = min(patched.rgb, vec3(patched.a));
		COLOR = mix(c, patched, m);
	}
}
