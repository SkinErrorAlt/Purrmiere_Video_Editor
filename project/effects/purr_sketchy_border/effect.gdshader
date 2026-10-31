shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform int lines : hint_range(1, 4) = 2;
uniform float inset : hint_range(0.0, 200.0) = 22.0;
uniform float wobble : hint_range(0.0, 20.0) = 4.0;
uniform float overshoot : hint_range(0.0, 80.0) = 18.0;
uniform float width : hint_range(0.5, 12.0) = 2.5;
uniform float boil : hint_range(0.0, 24.0) = 8.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P = UV * S;
	float fr = boil > 0.0 ? floor(clip_time * boil) : 0.0;
	float k = 0.0;
	for (int l = 0; l < 4; l++) {
		if (l >= lines) {
			break;
		}
		float fl = float(l);
		float ins = inset + fl * width * 2.5;
		float sd = fr * 3.7 + fl * 11.0;
		float o1 = (vn(vec2(P.x * 0.01, sd)) - 0.5) * wobble * 2.0;
		float o2 = (vn(vec2(P.x * 0.01, sd + 5.0)) - 0.5) * wobble * 2.0;
		float o3 = (vn(vec2(P.y * 0.01, sd + 9.0)) - 0.5) * wobble * 2.0;
		float o4 = (vn(vec2(P.y * 0.01, sd + 13.0)) - 0.5) * wobble * 2.0;
		float ov = overshoot * (0.6 + 0.4 * h12(vec2(sd, 1.0)));
		float inx = step(ins - ov, P.x) * step(P.x, S.x - ins + ov);
		float iny = step(ins - ov, P.y) * step(P.y, S.y - ins + ov);
		float d = 99.0;
		d = min(d, abs(P.y - ins - o1) + (1.0 - inx) * 99.0);
		d = min(d, abs(P.y - (S.y - ins) - o2) + (1.0 - inx) * 99.0);
		d = min(d, abs(P.x - ins - o3) + (1.0 - iny) * 99.0);
		d = min(d, abs(P.x - (S.x - ins) - o4) + (1.0 - iny) * 99.0);
		k = max(k, smoothstep(width * 0.5 + 0.8, width * 0.5 - 0.4, d));
	}
	COLOR = mix(c, vec4(ink.rgb, 1.0), k * ink.a);
}
