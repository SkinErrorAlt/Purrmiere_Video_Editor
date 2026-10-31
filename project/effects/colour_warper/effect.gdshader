shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 from_1 : source_color = vec4(0.35, 0.6, 0.25, 1.0);
uniform vec4 to_1 : source_color = vec4(0.25, 0.55, 0.45, 1.0);
uniform vec4 from_2 : source_color = vec4(0.85, 0.6, 0.45, 1.0);
uniform vec4 to_2 : source_color = vec4(0.85, 0.6, 0.45, 1.0);
uniform vec4 from_3 : source_color = vec4(0.3, 0.45, 0.8, 1.0);
uniform vec4 to_3 : source_color = vec4(0.3, 0.45, 0.8, 1.0);
uniform float range : hint_range(0.01, 1.0) = 0.2;
uniform bool keep_lightness = true;

vec3 opp(vec3 c) {
	float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return vec3(y, c.b - y, c.r - y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 p = opp(rgb);
	vec3 f[3] = vec3[](opp(from_1.rgb), opp(from_2.rgb), opp(from_3.rgb));
	vec3 t[3] = vec3[](opp(to_1.rgb), opp(to_2.rgb), opp(to_3.rgb));
	vec3 shift = vec3(0.0);
	float r2 = range * range;
	for (int i = 0; i < 3; i++) {
		vec2 dd = p.yz - f[i].yz;
		float w = exp(-dot(dd, dd) / r2);
		shift += (t[i] - f[i]) * w;
	}
	p.yz += shift.yz;
	if (!keep_lightness) { p.x += shift.x; }
	float r = p.x + p.z;
	float b = p.x + p.y;
	float g = (p.x - 0.2126 * r - 0.0722 * b) / 0.7152;
	COLOR = vec4(clamp(vec3(r, g, b), 0.0, 1.0) * c.a, c.a);
}
