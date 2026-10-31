shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D picture : filter_linear, repeat_enable, hint_default_transparent;
uniform int h_source : hint_range(0, 5) = 0;
uniform int v_source : hint_range(0, 5) = 1;
uniform float h_amount : hint_range(-400.0, 400.0) = 20.0;
uniform float v_amount : hint_range(-400.0, 400.0) = 20.0;
uniform int placement : hint_range(0, 1) = 0;
uniform bool wrap = false;
uniform vec2 tex_size;
uniform float px_scale;

float pick(vec4 m, int s) {
	if (s == 0) { return m.r; }
	if (s == 1) { return m.g; }
	if (s == 2) { return m.b; }
	if (s == 3) { return dot(m.rgb, vec3(0.299, 0.587, 0.114)); }
	if (s == 4) { return m.a; }
	return 0.5;
}

void fragment() {
	vec2 tsz = max(vec2(textureSize(picture, 0)), vec2(1.0));
	vec2 muv = placement == 1 ? UV * tex_size / (tsz * max(px_scale, 0.0001)) : UV;
	vec4 m = texture(picture, muv);
	float on = step(0.0001, m.a);
	vec3 col = m.a > 0.0001 ? m.rgb / m.a : vec3(0.5);
	vec4 mm = vec4(col, m.a);
	vec2 shift = vec2((pick(mm, h_source) - 0.5) * 2.0 * h_amount, (pick(mm, v_source) - 0.5) * 2.0 * v_amount);
	shift *= on * max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	vec2 uv = UV + shift;
	bool outside = !wrap && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0);
	if (wrap) { uv = fract(uv); }
	COLOR = outside ? vec4(0.0) : texture(TEXTURE, uv);
}
