shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(8.0, 160.0) = 36.0;
uniform float detail : hint_range(0.0, 1.0) = 0.5;
uniform float gap : hint_range(0.0, 0.4) = 0.08;
uniform vec4 ground : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

float var4(sampler2D tx, vec2 cl, float cs, vec2 k) {
	vec3 a = unp(texture(tx, (cl + vec2(0.25, 0.25)) * cs * k));
	vec3 b = unp(texture(tx, (cl + vec2(0.75, 0.25)) * cs * k));
	vec3 d = unp(texture(tx, (cl + vec2(0.25, 0.75)) * cs * k));
	vec3 e = unp(texture(tx, (cl + vec2(0.75, 0.75)) * cs * k));
	vec3 m = (a + b + d + e) * 0.25;
	return dot(abs(a - m) + abs(b - m) + abs(d - m) + abs(e - m), vec3(1.0));
}

void fragment() {
	vec2 k = px_scale / max(tex_size, vec2(1.0));
	vec2 P = PX(UV);
	float cs = cell;
	float th = (1.0 - detail) * 0.8 + 0.05;
	for (int lv = 0; lv < 3; lv++) {
		vec2 cl = floor(P / cs);
		if (lv < 2 && var4(TEXTURE, cl, cs, k) > th) {
			cs *= 0.5;
		}
	}
	vec2 cl = floor(P / cs);
	vec2 f = P / cs - cl - 0.5;
	vec4 c = texture(TEXTURE, (cl + 0.5) * cs * k);
	float d = (length(f) - (0.5 - gap * 0.5)) * cs;
	float in_c = smoothstep(0.7, -0.7, d);
	vec3 s = unp(c) * (1.0 + 0.15 * (0.2 - length(f + vec2(0.15))));
	COLOR = mix(vec4(ground.rgb, 1.0), pm(s, 1.0), in_c) * step(0.01, texture(TEXTURE, UV).a);
}
