shader_type canvas_item;
render_mode blend_disabled;

uniform float zoom : hint_range(0.5, 4.0) = 1.7;
uniform vec2 offset = vec2(0.15, 0.0);
uniform float turn : hint_range(-180.0, 180.0) = 0.0;
uniform int fill : hint_range(0, 1) = 0;
uniform vec4 tint : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.85;
uniform float contrast : hint_range(0.2, 3.0) = 1.3;
uniform vec2 tex_size = vec2(1.0, 1.0);

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - 0.5 - offset) * vec2(asp, 1.0);
	q = rot(radians(turn)) * q / zoom;
	vec4 c2 = texture(TEXTURE, clamp(q / vec2(asp, 1.0) + 0.5, vec2(0.0), vec2(1.0)));
	vec3 s2 = vec3(lum(unp(c2))) * tint.rgb * 1.2;
	float l = clamp((lum(s) - 0.5) * contrast + 0.5, 0.0, 1.0);
	float m = fill == 0 ? 1.0 - l : l;
	vec3 scr = 1.0 - (1.0 - s) * (1.0 - s2);
	vec3 o = mix(s, mix(scr, s2, 0.5), m * amount);
	COLOR = pm(o, c.a);
}
