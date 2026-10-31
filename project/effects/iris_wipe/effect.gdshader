shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.5) = 0.5;
uniform int shape : hint_range(0, 3) = 0;
uniform float feather : hint_range(0.0, 0.5) = 0.03;
uniform vec2 centre = vec2(0.5, 0.5);
uniform bool invert = false;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float t;
	if (shape == 1) {
		t = (abs(d.x) + abs(d.y)) * 1.2;
	} else if (shape == 3) {
		vec2 ad = abs(d);
		t = min(max(ad.x, ad.y / 0.35), max(ad.x / 0.35, ad.y));
	} else if (shape == 2) {
		t = max(abs(d.x), abs(d.y)) * 1.6;
	} else {
		t = length(d) * 1.4;
	}
	float soft = max(feather, 0.0001);
	float keep = smoothstep(progress + soft, progress - soft, t);
	if (invert) { keep = 1.0 - keep; }
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
