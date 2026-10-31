shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float thickness : hint_range(0.0, 60.0) = 4.0;
uniform bool outside = true;
uniform float softness : hint_range(0.0, 1.0) = 0.2;
uniform bool hide_fill = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float r = thickness * max(px_scale, 0.0001);
	float near = outside ? 0.0 : 1.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) / 12.0 * 6.28318530718;
		vec2 off = vec2(cos(ang), sin(ang)) * r / size;
		float sa = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0))).a;
		near = outside ? max(near, sa) : min(near, sa);
	}
	float band = outside ? clamp(near - a, 0.0, 1.0) : clamp(a - near, 0.0, 1.0);
	band = mix(step(0.02, band), smoothstep(0.0, 0.6, band), softness);
	float fill_a = hide_fill ? 0.0 : a;
	float oa = clamp(max(fill_a, band * colour.a), 0.0, 1.0);
	vec3 o = mix(rgb, colour.rgb, band);
	if (oa < 0.0001) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
