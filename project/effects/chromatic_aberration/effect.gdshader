shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 40.0) = 4.0;
uniform float falloff : hint_range(0.0, 4.0) = 1.5;
uniform vec2 centre = vec2(0.5, 0.5);
uniform bool sideways = false;
uniform vec2 tex_size;
uniform float px_scale;
uniform bool spill_out = false;

void fragment() {
	vec2 d = UV - centre;
	float r = length(d);
	float amount = strength * max(px_scale, 0.0001) * pow(clamp(r * 2.0, 0.0, 1.0), max(falloff, 0.0));
	vec2 dir = sideways ? vec2(1.0, 0.0) : (r > 0.0001 ? d / r : vec2(0.0));
	vec2 off = dir * amount / max(tex_size, vec2(1.0));
	vec4 cr = texture(TEXTURE, UV + off);
	vec4 cg = texture(TEXTURE, UV);
	vec4 cb = texture(TEXTURE, UV - off);
	if (spill_out) {
		COLOR = vec4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a)));
	} else {
		float a = cg.a;
		vec3 rgb = vec3(cr.a > 0.0001 ? cr.r / cr.a : 0.0, cg.a > 0.0001 ? cg.g / cg.a : 0.0, cb.a > 0.0001 ? cb.b / cb.a : 0.0);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
