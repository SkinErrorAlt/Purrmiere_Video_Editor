shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 sky_top : source_color = vec4(0.08, 0.02, 0.22, 1.0);
uniform vec4 sky_low : source_color = vec4(1.0, 0.32, 0.6, 1.0);
uniform vec4 sun_top : source_color = vec4(1.0, 0.92, 0.35, 1.0);
uniform vec4 sun_low : source_color = vec4(1.0, 0.25, 0.6, 1.0);
uniform vec4 grid_colour : source_color = vec4(1.0, 0.25, 0.85, 1.0);
uniform float horizon : hint_range(0.2, 0.9) = 0.62;
uniform float sun_size : hint_range(0.0, 0.6) = 0.28;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform int placement : hint_range(0, 2) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
vec4 place(vec4 c, vec3 g, float ga, int m) { vec4 t = vec4(clamp(g, 0.0, 1.0) * ga, ga); if (m == 0) { return over(c, t); } if (m == 1) { return over(t, c); } return t; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 h = vec2((UV.x - 0.5) * asp, UV.y);
	float hy = horizon;
	vec3 g = mix(sky_top.rgb, sky_low.rgb, pow(clamp(UV.y / hy, 0.0, 1.0), 2.2));
	vec2 sc = vec2(0.0, hy - sun_size * 0.55);
	float r = length(h - sc);
	float sy = clamp((UV.y - (sc.y - sun_size)) / (2.0 * sun_size), 0.0, 1.0);
	float cut = step(0.45, sy) * step(fract((UV.y - sc.y) * 28.0 / max(sun_size, 0.01) * 0.25), (sy - 0.45) * 1.3);
	float sun = smoothstep(sun_size + 0.003, sun_size - 0.003, r) * (1.0 - cut);
	g = mix(g, mix(sun_top.rgb, sun_low.rgb, sy), sun);
	g += sky_low.rgb * exp(-max(r - sun_size, 0.0) * 9.0) * 0.25 * step(UV.y, hy);
	if (UV.y > hy) {
		float dy = UV.y - hy;
		float z = 0.5 / max(dy, 0.0005);
		float u = h.x * z * 2.0;
		float v = z - clip_time * speed;
		float dx = min(fract(u), 1.0 - fract(u)) / max(fwidth(u), 0.00001);
		float dz = min(fract(v), 1.0 - fract(v)) / max(fwidth(v), 0.00001);
		float ln = max(1.0 - smoothstep(1.0, 2.6, dx), 1.0 - smoothstep(1.0, 2.6, dz));
		float fade = smoothstep(0.0, 0.25, dy);
		g = mix(sky_top.rgb * 0.4, sky_top.rgb * 0.8, fade);
		g += grid_colour.rgb * ln * (0.4 + fade);
		g += sky_low.rgb * exp(-dy * 30.0) * 0.8;
	}
	COLOR = place(c, g, 1.0, placement);
}
