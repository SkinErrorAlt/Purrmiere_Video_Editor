shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float width : hint_range(0.0, 4.0) = 0.8;
uniform float height : hint_range(0.0, 4.0) = 0.5;
uniform float thickness : hint_range(0.0, 1.0) = 0.03;
uniform float softness : hint_range(0.0, 0.3) = 0.003;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform vec4 colour : source_color = vec4(1.0);
uniform bool on_original = true;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float r = radians(rotation);
	d = vec2(cos(r) * d.x + sin(r) * d.y, -sin(r) * d.x + cos(r) * d.y);
	vec2 semi = max(vec2(width, height) * 0.5, vec2(0.0001));
	float rr = length(d / semi);
	float sd = (rr - 1.0) * min(semi.x, semi.y);
	float s = max(softness, 0.0005);
	float k = thickness > 0.0 ? smoothstep(s, -s, abs(sd + thickness * 0.5) - thickness * 0.5) : smoothstep(s, -s, sd);
	k *= colour.a;
	vec4 base = on_original ? c : vec4(0.0);
	COLOR = base * (1.0 - k) + vec4(colour.rgb, 1.0) * k;
}
