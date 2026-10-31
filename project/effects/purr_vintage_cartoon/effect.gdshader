shader_type canvas_item;
render_mode blend_disabled;

uniform int levels : hint_range(2, 6) = 3;
uniform float outline : hint_range(0.0, 6.0) = 1.6;
uniform float tint : hint_range(0.0, 1.0) = 0.35;
uniform float flicker : hint_range(0.0, 1.0) = 0.4;
uniform float grain : hint_range(0.0, 1.0) = 0.4;
uniform float weave : hint_range(0.0, 10.0) = 1.5;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

void fragment() {
	float fr = floor(clip_time * 12.0);
	vec2 wv = (h22(vec2(fr, 2.0)) - 0.5) * TX(weave);
	vec2 uv = UV + wv;
	vec4 c = texture(TEXTURE, uv);
	float l = lum(unp(c));
	float lv = float(levels - 1);
	l = floor(l * lv + 0.5) / lv;
	float e = edg(TEXTURE, uv, TX(max(outline, 0.01)));
	l *= 1.0 - smoothstep(0.25, 0.45, e) * step(0.01, outline);
	l *= 1.0 + (h12(vec2(fr, 9.0)) - 0.5) * flicker * 0.35;
	vec2 P = PX(UV);
	l += (h12(floor(P * 0.7) + fr * 3.0) - 0.5) * grain * 0.18;
	float dust = step(0.9985, h12(floor(P / 3.0) + fr * 1.7)) * grain;
	l = mix(l, 0.05, dust);
	vec2 vq = (UV - 0.5) * vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	l *= 1.0 - vignette * smoothstep(0.35, 0.75, length(vq));
	vec3 o = vec3(clamp(l, 0.0, 1.0)) * mix(vec3(1.0), vec3(1.05, 0.95, 0.78), tint);
	COLOR = pm(o, c.a);
}
