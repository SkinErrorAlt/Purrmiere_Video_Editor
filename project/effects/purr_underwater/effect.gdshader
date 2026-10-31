shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 deep : source_color = vec4(0.0, 0.32, 0.45, 1.0);
uniform float depth : hint_range(0.0, 1.0) = 0.5;
uniform float waves : hint_range(0.0, 30.0) = 6.0;
uniform float caustics : hint_range(0.0, 1.0) = 0.5;
uniform float rays : hint_range(0.0, 1.0) = 0.5;
uniform float specks : hint_range(0.0, 1.0) = 0.4;
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec4 vor(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); float d1 = 8.0; float d2 = 8.0; vec2 c = vec2(0.0); for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) { vec2 g = vec2(float(x), float(y)); vec2 o = g + h22(i + g); float d = length(o - f); if (d < d1) { d2 = d1; d1 = d; c = i + o; } else if (d < d2) { d2 = d; } } } return vec4(c, d1, d2 - d1); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec2 P = PX(UV);
	float t = clip_time * speed;
	vec2 w = vec2(vn(P * 0.008 + vec2(t * 0.4, 0.0)), vn(P * 0.008 + vec2(3.1, t * 0.35))) - 0.5;
	vec4 c = texture(TEXTURE, UV + w * TX(waves) * 2.0);
	vec3 s = unp(c);
	vec4 v = vor(P * 0.012 + vec2(t * 0.15, t * 0.1));
	vec4 v2 = vor(P * 0.019 - vec2(t * 0.12, -t * 0.08) + 4.0);
	float ca = pow(1.0 - smoothstep(0.0, 0.18, v.w), 3.0) + pow(1.0 - smoothstep(0.0, 0.18, v2.w), 3.0) * 0.6;
	float ry = vn(vec2(UV.x * 7.0 + UV.y * 2.5, t * 0.25)) * vn(vec2(UV.x * 13.0 + UV.y * 4.0, t * 0.2 + 5.0));
	ry = smoothstep(0.15, 0.5, ry) * (1.0 - UV.y);
	vec2 sp = P / 6.0 + vec2(sin(t + floor(P.x / 60.0)) * 0.3, -t * 2.0);
	float sk = step(0.996, h12(floor(sp))) * smoothstep(0.5, 0.1, length(fract(sp) - 0.5));
	vec3 g = mix(s, s * deep.rgb * 1.6 + deep.rgb * 0.25, depth);
	g = mix(g, deep.rgb, depth * 0.35 * UV.y);
	g += vec3(0.75, 1.0, 0.95) * ca * caustics * 0.35 * (1.0 - UV.y * 0.6);
	g += vec3(0.8, 1.0, 0.95) * ry * rays * 0.5;
	g += vec3(0.85) * sk * specks;
	COLOR = pm(g, c.a);
}
