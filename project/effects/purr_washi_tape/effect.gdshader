shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 tape_colour : source_color = vec4(1.0, 0.7, 0.8, 0.85);
uniform int pattern : hint_range(0, 3) = 2;
uniform vec4 pattern_colour : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform int corners : hint_range(0, 2) = 1;
uniform float tape_width : hint_range(10.0, 300.0) = 70.0;
uniform float tape_len : hint_range(30.0, 800.0) = 150.0;
uniform float border : hint_range(0.0, 80.0) = 16.0;
uniform float margin : hint_range(0.0, 0.3) = 0.13;
uniform float tilt : hint_range(-15.0, 15.0) = 2.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

float rbox(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float sde(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

void fragment() {
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P = rot(radians(-tilt)) * (UV * S - S * 0.5);
	vec2 hb = S * 0.5 - margin * S.y;
	float dph = rbox(P, hb);
	vec2 ib = hb - border;
	vec2 suv = P / max(ib, vec2(1.0)) * 0.5 + 0.5;
	vec4 c = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	float pic = smoothstep(0.8, -0.8, rbox(P, ib));
	float photo = smoothstep(0.8, -0.8, dph);
	vec4 o = mix(vec4(0.98, 0.97, 0.95, 1.0), over(c, vec4(0.98, 0.97, 0.95, 1.0)), pic) * photo;
	float sd = rbox(P - vec2(6.0, 9.0), hb);
	float sha = (1.0 - smoothstep(-4.0, 22.0, sd)) * shadow * 0.5;
	o = o + vec4(0.0, 0.0, 0.0, sha) * (1.0 - o.a);
	for (int i = 0; i < 4; i++) {
		bool use = corners == 0 || (corners == 1 && i < 2) || (corners == 2 && (i == 0 || i == 3));
		if (!use) {
			continue;
		}
		vec2 sg = vec2(i == 0 || i == 2 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0);
		vec2 cn = hb * sg - sg * tape_width * 0.2;
		float an = sg.x * sg.y * 0.7854;
		vec2 lp = rot(an) * (P - cn);
		float tear = abs(fract(lp.y / 9.0) - 0.5) * 7.0;
		float inx = step(abs(lp.x), tape_len * 0.5 - tear);
		float iny = smoothstep(0.8, -0.8, abs(lp.y) - tape_width * 0.5);
		float tp = inx * iny;
		float pt = 0.0;
		if (pattern == 1) {
			pt = smoothstep(0.32, 0.26, length(fract(lp / 14.0) - 0.5));
		} else if (pattern == 2) {
			pt = step(0.5, fract((lp.x + lp.y) / 16.0));
		} else if (pattern == 3) {
			vec2 f = (fract(lp / 26.0) - 0.5) * 2.2;
			float d = sde(f - vec2(0.0, 0.12), vec2(0.3, 0.24));
			d = min(d, length(f - vec2(-0.33, -0.2)) - 0.12);
			d = min(d, length(f - vec2(-0.12, -0.38)) - 0.12);
			d = min(d, length(f - vec2(0.12, -0.38)) - 0.12);
			d = min(d, length(f - vec2(0.33, -0.2)) - 0.12);
			pt = smoothstep(0.05, -0.05, d);
		}
		vec3 tc = mix(tape_colour.rgb, pattern_colour.rgb, pt * pattern_colour.a);
		float ta = tp * tape_colour.a;
		o = vec4(tc * ta, ta) + o * (1.0 - ta);
	}
	COLOR = o;
}
