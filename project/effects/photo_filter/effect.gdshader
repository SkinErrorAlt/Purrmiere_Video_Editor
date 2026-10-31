shader_type canvas_item;
render_mode blend_disabled;

uniform int filter_kind : hint_range(0, 15) = 0;
uniform float density : hint_range(0.0, 1.0) = 0.25;
uniform bool preserve_luminosity = true;
uniform vec4 colour : source_color = vec4(0.93, 0.54, 0.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

const vec3 FILTERS[15] = vec3[15](
	vec3(236.0, 138.0, 0.0) / 255.0,
	vec3(250.0, 150.0, 0.0) / 255.0,
	vec3(235.0, 177.0, 19.0) / 255.0,
	vec3(0.0, 109.0, 255.0) / 255.0,
	vec3(0.0, 93.0, 255.0) / 255.0,
	vec3(0.0, 181.0, 255.0) / 255.0,
	vec3(234.0, 26.0, 26.0) / 255.0,
	vec3(243.0, 132.0, 23.0) / 255.0,
	vec3(249.0, 227.0, 28.0) / 255.0,
	vec3(25.0, 201.0, 25.0) / 255.0,
	vec3(29.0, 203.0, 234.0) / 255.0,
	vec3(29.0, 53.0, 234.0) / 255.0,
	vec3(155.0, 29.0, 234.0) / 255.0,
	vec3(227.0, 24.0, 227.0) / 255.0,
	vec3(172.0, 122.0, 51.0) / 255.0
);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 tint = filter_kind >= 15 ? clamp(colour.rgb, 0.0, 1.0) : FILTERS[clamp(filter_kind, 0, 14)];
	vec3 filtered = mix(rgb, rgb * tint, density);
	if (preserve_luminosity) {
		filtered += vec3(dot(rgb, LUMA) - dot(filtered, LUMA));
	}
	COLOR = vec4(clamp(filtered, 0.0, 1.0) * a, a);
}
