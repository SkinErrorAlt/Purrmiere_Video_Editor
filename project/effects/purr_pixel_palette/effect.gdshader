shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(1.0, 40.0) = 6.0;
uniform int palette : hint_range(0, 5) = 2;
uniform float dither : hint_range(0.0, 1.0) = 0.5;
uniform float contrast : hint_range(0.0, 2.0) = 1.1;
uniform float grid : hint_range(0.0, 1.0) = 0.12;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

const vec3 PAL[48] = vec3[](
	vec3(0.06, 0.22, 0.06), vec3(0.06, 0.22, 0.06), vec3(0.19, 0.38, 0.19), vec3(0.19, 0.38, 0.19), vec3(0.55, 0.67, 0.06), vec3(0.55, 0.67, 0.06), vec3(0.61, 0.74, 0.06), vec3(0.61, 0.74, 0.06),
	vec3(0.0), vec3(1.0), vec3(0.85, 0.2, 0.2), vec3(0.3, 0.85, 0.85), vec3(0.6, 0.3, 0.75), vec3(0.35, 0.75, 0.3), vec3(0.2, 0.25, 0.75), vec3(0.95, 0.9, 0.35),
	vec3(0.16, 0.12, 0.2), vec3(0.42, 0.3, 0.5), vec3(0.95, 0.6, 0.7), vec3(1.0, 0.85, 0.75), vec3(0.6, 0.85, 0.9), vec3(0.75, 0.65, 0.95), vec3(0.98, 0.96, 0.92), vec3(0.55, 0.8, 0.65),
	vec3(0.04, 0.02, 0.1), vec3(0.2, 0.05, 0.35), vec3(0.95, 0.1, 0.6), vec3(0.1, 0.9, 0.95), vec3(0.5, 0.2, 0.9), vec3(1.0, 0.85, 0.2), vec3(0.95, 0.95, 1.0), vec3(0.1, 0.35, 0.7),
	vec3(0.1, 0.06, 0.03), vec3(0.22, 0.14, 0.08), vec3(0.35, 0.24, 0.15), vec3(0.48, 0.35, 0.23), vec3(0.62, 0.49, 0.34), vec3(0.76, 0.64, 0.47), vec3(0.88, 0.79, 0.63), vec3(1.0, 0.93, 0.8),
	vec3(0.0), vec3(1.0), vec3(0.0), vec3(1.0), vec3(0.0), vec3(1.0), vec3(0.0), vec3(1.0));
const float BY[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 P = PX(UV) / size;
	vec2 cell = floor(P);
	vec2 cuv = (cell + 0.5) * size * px_scale / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 s = clamp((unp(c) - 0.5) * contrast + 0.5, 0.0, 1.0);
	int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	s += (BY[bi] / 16.0 - 0.47) * dither * 0.35;
	vec3 best = PAL[palette * 8];
	float bd = 99.0;
	for (int i = 0; i < 8; i++) {
		vec3 p = PAL[palette * 8 + i];
		vec3 d = (s - p) * vec3(0.9, 1.2, 0.7);
		float dd = dot(d, d);
		if (dd < bd) {
			bd = dd;
			best = p;
		}
	}
	vec2 f = fract(P);
	float gl = step(min(f.x, f.y), 1.0 / size) * grid;
	COLOR = pm(best * (1.0 - gl * 0.5), step(0.5, c.a));
}
