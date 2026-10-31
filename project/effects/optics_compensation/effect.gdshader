shader_type canvas_item;
render_mode blend_disabled;

uniform float distortion : hint_range(-1.0, 1.0) = 0.0;
uniform float scale_fit : hint_range(0.25, 2.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float chroma : hint_range(-0.1, 0.1) = 0.0;
uniform bool fill_edges = false;
uniform vec2 tex_size;

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - centre) * aspect / max(scale_fit, 0.0001);
	float r2 = dot(p, p);
	float k = 1.0 + distortion * r2;
	vec2 base = centre + p * k / aspect;
	vec2 uv_r = centre + p * (k * (1.0 + chroma)) / aspect;
	vec2 uv_b = centre + p * (k * (1.0 - chroma)) / aspect;
	bool outside = base.x < 0.0 || base.x > 1.0 || base.y < 0.0 || base.y > 1.0;
	if (outside && !fill_edges) {
		COLOR = vec4(0.0);
	} else {
		vec4 cg = texture(TEXTURE, clamp(base, vec2(0.0), vec2(1.0)));
		vec4 cr = texture(TEXTURE, clamp(uv_r, vec2(0.0), vec2(1.0)));
		vec4 cb = texture(TEXTURE, clamp(uv_b, vec2(0.0), vec2(1.0)));
		float a = cg.a;
		vec3 rgb = vec3(cr.a > 0.0001 ? cr.r / cr.a : 0.0, cg.a > 0.0001 ? cg.g / cg.a : 0.0, cb.a > 0.0001 ? cb.b / cb.a : 0.0);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
