shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 key_colour : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float hue_tolerance : hint_range(0.0, 1.0) = 0.2;
uniform float luma_tolerance : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.15;
uniform bool invert = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	float lk = dot(key_colour.rgb, w);
	float lc = dot(rgb, w);
	vec3 ck = key_colour.rgb - vec3(lk);
	vec3 cc = rgb - vec3(lc);
	float hue_d = length(cc - ck) / 1.4142136;
	float luma_d = abs(lc - lk);
	float soft = max(softness, 0.0001);
	float hue_hit = 1.0 - smoothstep(max(hue_tolerance - soft, 0.0), hue_tolerance + soft, hue_d);
	float luma_hit = 1.0 - smoothstep(max(luma_tolerance - soft, 0.0), luma_tolerance + soft, luma_d);
	float hit = hue_hit * luma_hit;
	float keep = invert ? hit : 1.0 - hit;
	float oa = a * clamp(keep, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
