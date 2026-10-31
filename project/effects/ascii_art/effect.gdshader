shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(4.0, 64.0) = 10.0;
uniform vec4 ink : source_color = vec4(0.85, 1.0, 0.85, 1.0);
uniform vec4 paper : source_color = vec4(0.02, 0.04, 0.02, 1.0);
uniform bool keep_colour = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float c = max(cell * max(px_scale, 0.0001), 2.0);
	vec2 grid = floor(UV * size / c);
	vec2 centre_uv = (grid + 0.5) * c / size;
	vec4 s = texture(TEXTURE, clamp(centre_uv, vec2(0.0), vec2(1.0)));
	float a = s.a;
	vec3 sr = a > 0.0001 ? s.rgb / a : vec3(0.0);
	float luma = clamp(dot(sr, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
	vec2 f = fract(UV * size / c);
	float on = 0.0;
	if (luma > 0.85) {
		on = 0.0;
	} else if (luma > 0.65) {
		on = step(0.45, f.x) * step(0.45, f.y) * step(f.x, 0.55) * step(f.y, 0.55);
	} else if (luma > 0.45) {
		on = max(step(0.45, f.x) * step(f.x, 0.55), step(0.45, f.y) * step(f.y, 0.55));
	} else if (luma > 0.25) {
		on = max(step(abs(f.x - f.y), 0.12), step(abs(f.x + f.y - 1.0), 0.12));
	} else {
		on = step(0.1, f.x) * step(f.x, 0.9) * step(0.1, f.y) * step(f.y, 0.9);
	}
	vec3 lit = keep_colour ? sr : ink.rgb;
	vec3 rgb = mix(paper.rgb, lit, on);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
