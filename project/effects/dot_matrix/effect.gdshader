shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(3.0, 64.0) = 10.0;
uniform float lamp : hint_range(0.1, 1.0) = 0.8;
uniform float glow : hint_range(0.0, 2.0) = 0.5;
uniform vec4 board : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform bool single_colour = false;
uniform vec4 lamp_colour : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float c = max(cell * max(px_scale, 0.0001), 3.0);
	vec2 grid = floor(UV * size / c);
	vec2 centre_uv = (grid + 0.5) * c / size;
	vec4 s = texture(TEXTURE, clamp(centre_uv, vec2(0.0), vec2(1.0)));
	float a = s.a;
	vec3 sr = a > 0.0001 ? s.rgb / a : vec3(0.0);
	vec2 f = fract(UV * size / c) - 0.5;
	float d = length(f) / max(lamp * 0.5, 0.0001);
	float on = 1.0 - smoothstep(0.7, 1.0, d);
	float halo = exp(-d * d * 1.5) * glow;
	vec3 lit = single_colour ? lamp_colour.rgb * dot(sr, vec3(0.2126, 0.7152, 0.0722)) : sr;
	vec3 rgb = board.rgb + lit * (on + halo);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
