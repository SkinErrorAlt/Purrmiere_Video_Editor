shader_type canvas_item;
render_mode blend_disabled;

uniform int bands : hint_range(2, 8) = 3;
uniform float softness : hint_range(0.0, 1.0) = 0.15;
uniform float saturation : hint_range(0.0, 2.0) = 1.3;
uniform float highlight : hint_range(0.0, 1.0) = 0.4;
uniform float outline : hint_range(0.0, 6.0) = 1.5;
uniform float threshold : hint_range(0.0, 1.0) = 0.3;
uniform vec4 ink : source_color = vec4(0.08, 0.05, 0.12, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 t = TX(1.0);
	vec4 s4 = c * 0.4 + (texture(TEXTURE, UV + vec2(t.x, 0.0)) + texture(TEXTURE, UV - vec2(t.x, 0.0)) + texture(TEXTURE, UV + vec2(0.0, t.y)) + texture(TEXTURE, UV - vec2(0.0, t.y))) * 0.15;
	vec3 s = unp(s4);
	float l = lum(s);
	float b = float(bands);
	float f = l * b;
	float q = (floor(f) + smoothstep(0.5 - softness * 0.5, 0.5 + softness * 0.5 + 0.001, fract(f))) / b;
	vec3 base = s / max(l, 0.03) * max(q, 0.04);
	base = mix(vec3(lum(base)), base, saturation);
	base = mix(base, vec3(1.0), highlight * smoothstep(0.82, 0.9, l));
	float e = edg(TEXTURE, UV, TX(max(outline, 0.01)));
	float k = smoothstep(threshold, threshold + 0.15, e) * step(0.01, outline);
	COLOR = pm(mix(base, ink.rgb, k * ink.a), max(c.a, k * ink.a * step(0.01, s4.a)));
}
