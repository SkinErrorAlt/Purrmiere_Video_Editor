shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float strength : hint_range(0.0, 8.0) = 1.5;
uniform float edge_width : hint_range(0.5, 16.0) = 2.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.1;
uniform bool keep_picture = true;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 t = vec2(max(edge_width * max(px_scale, 0.0001), 0.5)) / max(tex_size, vec2(1.0));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec4 sl = texture(TEXTURE, UV - vec2(t.x, 0.0));
	vec4 sr = texture(TEXTURE, UV + vec2(t.x, 0.0));
	vec4 su = texture(TEXTURE, UV - vec2(0.0, t.y));
	vec4 sd = texture(TEXTURE, UV + vec2(0.0, t.y));
	float l = dot(sl.a > 0.0001 ? sl.rgb / sl.a : vec3(0.0), w);
	float r = dot(sr.a > 0.0001 ? sr.rgb / sr.a : vec3(0.0), w);
	float u = dot(su.a > 0.0001 ? su.rgb / su.a : vec3(0.0), w);
	float d = dot(sd.a > 0.0001 ? sd.rgb / sd.a : vec3(0.0), w);
	float e = clamp(length(vec2(r - l, d - u)) * strength, 0.0, 1.0);
	e = e < threshold ? 0.0 : e;
	vec3 glow = colour.rgb * e * colour.a;
	rgb = keep_picture ? rgb + glow : glow;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
