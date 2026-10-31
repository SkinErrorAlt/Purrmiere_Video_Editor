shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int shape : hint_range(0, 2) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float width : hint_range(0.005, 0.5) = 0.06;
uniform float intensity : hint_range(0.0, 4.0) = 1.5;
uniform vec4 colour : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float a = radians(angle);
	float s = dot(d, vec2(cos(a), -sin(a)));
	float reach = 0.5 * (aspect + 1.0) + width;
	float e;
	if (shape == 1) { e = length(d) - progress * (length(vec2(aspect, 1.0)) + width); }
	else if (shape == 2) { e = abs(s) - progress * reach; }
	else { e = s - mix(-reach, reach, progress); }
	float keep = smoothstep(-0.002, 0.002, e);
	float live = smoothstep(0.0, 0.04, progress) * smoothstep(1.0, 0.96, progress);
	float l = exp(-abs(e) / max(width, 0.001)) * intensity * live * colour.a;
	vec4 o = c * keep;
	vec3 rgb = o.rgb + colour.rgb * l;
	float oa = clamp(max(o.a, l), 0.0, 1.0);
	COLOR = vec4(min(rgb, vec3(oa)), oa);
}
