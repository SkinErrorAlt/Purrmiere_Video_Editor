shader_type canvas_item;
render_mode blend_disabled;

uniform float tone_size : hint_range(2.0, 20.0) = 5.0;
uniform int style : hint_range(0, 2) = 0;
uniform float light_cut : hint_range(0.0, 1.0) = 0.72;
uniform float dark_cut : hint_range(0.0, 1.0) = 0.38;
uniform float black_cut : hint_range(0.0, 1.0) = 0.12;
uniform float line_width : hint_range(0.3, 6.0) = 1.5;
uniform float threshold : hint_range(0.0, 1.0) = 0.25;
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 paper : source_color = vec4(0.99, 0.98, 0.96, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

float tone(vec2 P, float cov) {
	if (style == 0) {
		vec2 q = rot(0.7854) * P / tone_size;
		float r = sqrt(cov) * 0.62;
		return smoothstep(r + 0.08, r - 0.08, length(fract(q) - 0.5));
	}
	vec2 q = rot(0.7854) * P / tone_size;
	float a = smoothstep(cov * 0.5 + 0.08, cov * 0.5 - 0.08, abs(fract(q.y) - 0.5));
	if (style == 2) {
		a = max(a, smoothstep(cov * 0.5 + 0.08, cov * 0.5 - 0.08, abs(fract(q.x) - 0.5)));
	}
	return a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = lum(unp(c));
	vec2 P = PX(UV);
	float k = 0.0;
	if (l < black_cut) {
		k = 1.0;
	} else if (l < dark_cut) {
		k = tone(P, 0.55);
	} else if (l < light_cut) {
		k = tone(P, 0.2);
	}
	float e = edg(TEXTURE, UV, TX(line_width));
	k = max(k, smoothstep(threshold, threshold + 0.15, e));
	COLOR = pm(mix(paper.rgb, ink.rgb, k), c.a);
}
