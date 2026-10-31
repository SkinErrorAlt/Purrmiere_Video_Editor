shader_type canvas_item;
render_mode blend_disabled;

uniform float brick : hint_range(4.0, 80.0) = 20.0;
uniform int palette : hint_range(0, 1) = 0;
uniform float stud : hint_range(0.0, 1.0) = 0.8;
uniform float bevel : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform float gap : hint_range(0.0, 0.3) = 0.05;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

const vec3 TP[12] = vec3[](vec3(0.8, 0.1, 0.1), vec3(0.98, 0.8, 0.1), vec3(0.05, 0.35, 0.75), vec3(0.15, 0.55, 0.2), vec3(0.95, 0.95, 0.93), vec3(0.08, 0.08, 0.09), vec3(0.95, 0.5, 0.1), vec3(0.85, 0.75, 0.55), vec3(0.35, 0.36, 0.38), vec3(0.65, 0.66, 0.67), vec3(0.95, 0.55, 0.7), vec3(0.45, 0.75, 0.9));

void fragment() {
	vec2 P = PX(UV) / brick;
	vec2 cell = floor(P);
	vec2 f = fract(P) - 0.5;
	vec2 cuv = (cell + 0.5) * brick * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 s = unp(c);
	vec3 col = s;
	if (palette == 0) {
		float bd = 99.0;
		for (int i = 0; i < 12; i++) {
			vec3 d = (s - TP[i]) * vec3(1.0, 1.3, 0.8);
			float dd = dot(d, d);
			if (dd < bd) {
				bd = dd;
				col = TP[i];
			}
		}
	}
	float la = radians(light_angle);
	vec2 L = vec2(cos(la), sin(la));
	float edge = max(abs(f.x), abs(f.y));
	float bv = smoothstep(0.38, 0.5 - gap, edge) * bevel;
	vec2 en = abs(f.x) > abs(f.y) ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y));
	float lit = 1.0 + bv * dot(en, L) * 0.6;
	float r = length(f);
	float sr = 0.28;
	float sc = smoothstep(sr + 0.03, sr - 0.01, r);
	float side = smoothstep(sr + 0.03, sr, r) * smoothstep(sr - 0.08, sr - 0.02, r);
	float sdl = dot(normalize(f + 0.0001), L);
	float shadow = smoothstep(sr + 0.12, sr, length(f + L * 0.08)) * (1.0 - sc);
	lit *= 1.0 - shadow * 0.25 * stud;
	lit *= 1.0 + side * sdl * 0.5 * stud + sc * 0.06 * stud;
	float gp = step(0.5 - gap, edge);
	vec3 o = col * lit * (1.0 - gp * 0.6);
	COLOR = pm(o, step(0.5, c.a));
}
