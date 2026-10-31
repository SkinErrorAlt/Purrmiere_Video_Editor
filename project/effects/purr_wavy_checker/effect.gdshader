shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour_a : source_color = vec4(1.0, 0.55, 0.75, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float size : hint_range(10.0, 400.0) = 80.0;
uniform float wave : hint_range(0.0, 1.0) = 0.4;
uniform float speed : hint_range(-3.0, 3.0) = 0.4;
uniform float angle : hint_range(-180.0, 180.0) = 20.0;
uniform float floor : hint_range(0.0, 1.0) = 0.0;
uniform int placement : hint_range(0, 2) = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec4 place(vec4 c, vec3 g, float ga, int m) { vec4 t = vec4(clamp(g, 0.0, 1.0) * ga, ga); if (m == 0) { return over(c, t); } if (m == 1) { return over(t, c); } return t; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV) / size;
	vec2 S = tex_size / max(px_scale, 0.0001) / size;
	vec2 q = P - S * 0.5;
	if (floor > 0.0) {
		float y = UV.y - 0.35;
		float persp = mix(1.0, 0.25 / max(y, 0.01), floor);
		q = vec2(q.x * persp, mix(q.y, 4.0 / max(y, 0.01), floor));
	}
	q = rot(radians(angle)) * q;
	q.y += clip_time * speed;
	q += wave * 0.35 * vec2(sin(q.y * 1.3 + clip_time * 2.0), sin(q.x * 1.1 + clip_time * 1.6));
	vec2 f = fract(q * 0.5);
	float ch = step(0.5, f.x) == step(0.5, f.y) ? 1.0 : 0.0;
	vec2 g2 = abs(f - 0.5);
	float aa = fwidth(q.x) * 0.5 + 0.001;
	float edge = smoothstep(0.0, aa * 2.0, min(min(g2.x, g2.y), 0.5 - max(g2.x, g2.y)));
	vec3 g = mix(colour_b.rgb, colour_a.rgb, mix(0.5, ch, edge));
	float vis = floor > 0.0 ? smoothstep(0.35, 0.4, UV.y) : 1.0;
	g = mix(colour_b.rgb * 0.9, g, mix(1.0, vis, floor));
	COLOR = place(c, g, 1.0, placement);
}
