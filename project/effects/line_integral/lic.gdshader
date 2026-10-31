shader_type canvas_item;
render_mode blend_disabled;

uniform int smear = 0;
uniform int direction = 0;
uniform float stroke_length : hint_range(1.0, 200.0) = 16.0;
uniform float grain : hint_range(0.5, 10.0) = 1.5;
uniform float strength : hint_range(0.0, 1.0) = 0.7;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float grain_at(vec2 p, vec2 so) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i + so);
	float b = hash12(i + vec2(1.0, 0.0) + so);
	float c = hash12(i + vec2(0.0, 1.0) + so);
	float d = hash12(i + vec2(1.0, 1.0) + so);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 stroke_dir(sampler2D tex, vec2 uv) {
	vec2 j = texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).xy * 2.0 - 1.0;
	float ang = 0.5 * atan(j.y, j.x + 0.0000001);
	vec2 g = vec2(cos(ang), sin(ang));
	return direction == 0 ? vec2(-g.y, g.x) : g;
}

void fragment() {
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 c = texture(effect_tex, UV);
	float st = clamp(strength, 0.0, 1.0);
	if (st <= 0.0) {
		COLOR = c;
	} else {
		float sf = float(seed);
		vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
		float g_px = max(grain * ps, 0.5);
		float len_px = max(stroke_length * ps, 1.0);
		const int STEPS = 14;
		float step_px = len_px / float(STEPS);
		vec2 d0 = stroke_dir(TEXTURE, UV);
		float wsum = 1.0;
		float nsum = grain_at(UV * out_size / g_px, so);
		vec4 csum = c;
		for (int side = 0; side < 2; side++) {
			vec2 pos = UV;
			vec2 prev = side == 0 ? d0 : -d0;
			for (int i = 1; i <= STEPS; i++) {
				vec2 dir = stroke_dir(TEXTURE, pos);
				if (dot(dir, prev) < 0.0) {
					dir = -dir;
				}
				prev = dir;
				pos += dir * step_px / out_size;
				float w = 0.5 + 0.5 * cos(3.14159265 * float(i) / float(STEPS + 1));
				wsum += w;
				if (smear == 0) {
					nsum += grain_at(pos * out_size / g_px, so) * w;
				} else {
					csum += texture(effect_tex, clamp(pos, vec2(0.0), vec2(1.0))) * w;
				}
			}
		}
		if (smear == 0) {
			float lic = nsum / wsum;
			float m = 1.0 + (lic - 0.5) * 3.2 * st;
			COLOR = vec4(min(c.rgb * max(m, 0.0), vec3(c.a)), c.a);
		} else {
			COLOR = mix(c, csum / wsum, st);
		}
	}
}
