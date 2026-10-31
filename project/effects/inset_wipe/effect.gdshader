shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int corner : hint_range(0, 4) = 0;
uniform float feather : hint_range(0.0, 0.2) = 0.002;
uniform float border : hint_range(0.0, 40.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0);
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV;
	if (corner == 1 || corner == 2) { p.x = 1.0 - p.x; }
	if (corner == 2 || corner == 3) { p.y = 1.0 - p.y; }
	float d = corner == 4 ? max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0 : max(p.x, p.y);
	float f = max(feather, 0.0005);
	float edge = mix(-f, 1.0 + f, progress);
	float inside = smoothstep(edge + f, edge - f, d);
	float bw = border * max(px_scale, 0.0001) / max(min(tex_size.x, tex_size.y), 1.0) * (corner == 4 ? 2.0 : 1.0);
	float ring = bw > 0.0 && progress > 0.0 && progress < 1.0 ? smoothstep(bw + f, bw, abs(d - edge)) : 0.0;
	vec4 o = c * (1.0 - inside);
	o = o * (1.0 - ring * border_colour.a) + vec4(border_colour.rgb, 1.0) * ring * border_colour.a;
	COLOR = o;
}
