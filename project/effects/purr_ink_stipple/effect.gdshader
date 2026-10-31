shader_type canvas_item;
render_mode blend_disabled;

uniform float dot : hint_range(0.5, 10.0) = 1.6;
uniform float spacing : hint_range(1.0, 6.0) = 2.2;
uniform float darkness : hint_range(0.0, 2.0) = 1.1;
uniform vec4 ink : source_color = vec4(0.08, 0.07, 0.09, 1.0);
uniform vec4 paper : source_color = vec4(0.98, 0.97, 0.94, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 P = PX(UV);
	float cs = dot * spacing;
	float k = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		vec2 Q = P / cs + float(layer) * vec2(0.5, 0.31);
		vec2 cl = floor(Q);
		vec2 hh = h22(cl + float(layer) * 7.0);
		vec2 pos = cl + 0.2 + hh * 0.6;
		vec2 suv = (pos - float(layer) * vec2(0.5, 0.31)) * cs * px_scale / max(tex_size, vec2(1.0));
		float t = clamp((1.0 - lum(unp(texture(TEXTURE, suv)))) * darkness, 0.0, 1.0);
		float on = step(h12(cl + 3.3 + float(layer)), pow(smoothstep(0.12, 0.92, t), 1.8));
		float d = length(Q - pos) * cs;
		k = max(k, smoothstep(dot * 0.5 + 0.6, dot * 0.5 - 0.4, d) * on);
	}
	COLOR = pm(mix(paper.rgb, ink.rgb, k), c.a);
}
