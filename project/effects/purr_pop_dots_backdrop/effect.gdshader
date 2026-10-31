shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 bg : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 dot_colour : source_color = vec4(0.95, 0.25, 0.45, 1.0);
uniform float cell : hint_range(6.0, 200.0) = 34.0;
uniform float angle : hint_range(-180.0, 180.0) = 30.0;
uniform float speed : hint_range(-3.0, 3.0) = 0.2;
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
	vec2 P = rot(0.7854) * PX(UV) / cell + vec2(clip_time * speed, 0.0);
	vec2 f = fract(P) - 0.5;
	float an = radians(angle);
	float u = clamp(dot(UV - 0.5, vec2(cos(an), sin(an))) * 1.2 + 0.5, 0.0, 1.0);
	float r = mix(0.06, 0.62, u);
	float k = smoothstep(r + 0.8 / cell, r - 0.8 / cell, length(f));
	COLOR = place(c, mix(bg.rgb, dot_colour.rgb, k), 1.0, placement);
}
