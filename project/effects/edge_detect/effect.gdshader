shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 8.0) = 1.0;
uniform float edge_width : hint_range(0.5, 8.0) = 1.0;
uniform bool on_white = true;
uniform bool keep_colour = false;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 t = vec2(max(edge_width * max(px_scale, 0.0001), 0.5)) / max(tex_size, vec2(1.0));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec4 s_tl = texture(TEXTURE, UV + vec2(-t.x, -t.y));
	vec4 s_tc = texture(TEXTURE, UV + vec2(0.0, -t.y));
	vec4 s_tr = texture(TEXTURE, UV + vec2(t.x, -t.y));
	vec4 s_ml = texture(TEXTURE, UV + vec2(-t.x, 0.0));
	vec4 s_mr = texture(TEXTURE, UV + vec2(t.x, 0.0));
	vec4 s_bl = texture(TEXTURE, UV + vec2(-t.x, t.y));
	vec4 s_bc = texture(TEXTURE, UV + vec2(0.0, t.y));
	vec4 s_br = texture(TEXTURE, UV + vec2(t.x, t.y));
	float tl = dot(s_tl.a > 0.0001 ? s_tl.rgb / s_tl.a : vec3(0.0), w);
	float tc = dot(s_tc.a > 0.0001 ? s_tc.rgb / s_tc.a : vec3(0.0), w);
	float tr = dot(s_tr.a > 0.0001 ? s_tr.rgb / s_tr.a : vec3(0.0), w);
	float ml = dot(s_ml.a > 0.0001 ? s_ml.rgb / s_ml.a : vec3(0.0), w);
	float mr = dot(s_mr.a > 0.0001 ? s_mr.rgb / s_mr.a : vec3(0.0), w);
	float bl = dot(s_bl.a > 0.0001 ? s_bl.rgb / s_bl.a : vec3(0.0), w);
	float bc = dot(s_bc.a > 0.0001 ? s_bc.rgb / s_bc.a : vec3(0.0), w);
	float br = dot(s_br.a > 0.0001 ? s_br.rgb / s_br.a : vec3(0.0), w);
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float e = clamp(length(vec2(gx, gy)) * strength, 0.0, 1.0);
	e = e < threshold ? 0.0 : e;
	rgb = keep_colour ? rgb * e : (on_white ? vec3(1.0 - e) : vec3(e));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
