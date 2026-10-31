shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(3, 60) = 16;
uniform float smooth_px : hint_range(0.0, 20.0) = 4.0;
uniform float line_width : hint_range(0.3, 6.0) = 1.2;
uniform vec4 line_colour : source_color = vec4(0.35, 0.22, 0.12, 1.0);
uniform int fill : hint_range(0, 2) = 0;
uniform vec4 paper : source_color = vec4(0.96, 0.94, 0.88, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

vec3 tint(float h) {
	vec3 a = mix(vec3(0.38, 0.6, 0.42), vec3(0.75, 0.82, 0.5), smoothstep(0.0, 0.35, h));
	a = mix(a, vec3(0.88, 0.75, 0.5), smoothstep(0.3, 0.6, h));
	a = mix(a, vec3(0.7, 0.5, 0.38), smoothstep(0.55, 0.8, h));
	return mix(a, vec3(0.97, 0.96, 0.95), smoothstep(0.8, 0.95, h));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float h = lum(unp(c)) * 2.0;
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		h += lum(unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(smooth_px))));
	}
	h /= 8.0;
	float v = h * float(levels);
	float fw = max(fwidth(v), 0.0001);
	float dl = min(fract(v), 1.0 - fract(v)) / fw;
	float idx = step(mod(floor(v + 0.5), 5.0), 0.5);
	float w = line_width * px_scale * (1.0 + idx);
	float ln = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dl);
	vec3 base = fill == 0 ? tint(h) : (fill == 1 ? unp(c) : paper.rgb);
	COLOR = pm(mix(base, line_colour.rgb, ln), c.a);
}
