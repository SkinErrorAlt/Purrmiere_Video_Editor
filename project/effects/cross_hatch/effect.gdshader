shader_type canvas_item;
render_mode blend_disabled;

uniform float spacing : hint_range(2.0, 40.0) = 8.0;
uniform float thickness : hint_range(0.05, 1.0) = 0.35;
uniform int levels : hint_range(1, 4) = 4;
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 paper : source_color = vec4(0.96, 0.95, 0.9, 1.0);
uniform vec2 tex_size;
uniform float px_scale;

float hatch(vec2 px, float dir_x, float dir_y, float gap, float thick) {
	float v = px.x * dir_x + px.y * dir_y;
	float f = abs(fract(v / gap) - 0.5) * 2.0;
	return 1.0 - smoothstep(1.0 - thick, 1.0 - thick * 0.5, f);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 px = UV * tex_size;
	float gap = max(spacing * max(px_scale, 0.0001), 1.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float cover = 0.0;
	if (luma < 0.85 && levels >= 1) { cover = max(cover, hatch(px, 0.7071, 0.7071, gap, thickness)); }
	if (luma < 0.62 && levels >= 2) { cover = max(cover, hatch(px, 0.7071, -0.7071, gap, thickness)); }
	if (luma < 0.38 && levels >= 3) { cover = max(cover, hatch(px, 1.0, 0.0, gap, thickness)); }
	if (luma < 0.18 && levels >= 4) { cover = max(cover, hatch(px, 0.0, 1.0, gap, thickness)); }
	rgb = mix(paper.rgb, ink.rgb, cover);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
