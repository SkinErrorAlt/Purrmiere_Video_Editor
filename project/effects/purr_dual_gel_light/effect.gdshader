shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 left : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform vec4 right : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.9;
uniform float spread : hint_range(0.1, 1.0) = 0.6;
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float wrap : hint_range(0.0, 1.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 e = TX(3.0);
	float gx = lum(unp(texture(TEXTURE, UV + vec2(e.x, 0.0)))) - lum(unp(texture(TEXTURE, UV - vec2(e.x, 0.0))));
	float wl = smoothstep(spread + 0.2, 0.0, UV.x);
	float wr = smoothstep(1.0 - spread - 0.2, 1.0, UV.x);
	float fl = clamp(1.0 - gx * 8.0 * wrap, 0.2, 2.0);
	float fr = clamp(1.0 + gx * 8.0 * wrap, 0.2, 2.0);
	vec3 light = left.rgb * wl * fl + right.rgb * wr * fr;
	vec3 o = s * (1.0 - darken) + s * light * strength + light * strength * 0.05;
	COLOR = pm(o, c.a);
}
