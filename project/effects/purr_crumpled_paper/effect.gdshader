shader_type canvas_item;
render_mode blend_disabled;

uniform float crumple : hint_range(0.0, 1.0) = 0.6;
uniform float scale : hint_range(20.0, 600.0) = 140.0;
uniform float warp : hint_range(0.0, 20.0) = 3.0;
uniform int folds : hint_range(0, 6) = 2;
uniform float fold_strength : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform vec4 paper : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec4 vor(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); float d1 = 8.0; float d2 = 8.0; vec2 c = vec2(0.0); for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) { vec2 g = vec2(float(x), float(y)); vec2 o = g + h22(i + g); float d = length(o - f); if (d < d1) { d2 = d1; d1 = d; c = i + o; } else if (d < d2) { d2 = d; } } } return vec4(c, d1, d2 - d1); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec2 P = PX(UV);
	vec4 v = vor(P / scale);
	vec2 nh = h22(floor(v.xy) + 7.0) - 0.5;
	vec4 v2 = vor(P / (scale * 0.45) + 13.0);
	nh += (h22(floor(v2.xy) + 3.0) - 0.5) * 0.5;
	vec2 n = nh * crumple;
	vec4 c = texture(TEXTURE, UV + n * TX(warp) * 2.0);
	vec3 s = unp(c);
	float la = radians(light_angle);
	vec2 L = vec2(cos(la), sin(la));
	float sh = dot(n, L) * 0.6;
	sh -= (1.0 - smoothstep(0.0, 0.05, v.w)) * crumple * 0.15;
	sh += (1.0 - smoothstep(0.0, 0.04, v2.w)) * crumple * 0.06;
	if (folds > 0) {
		float fn = float(folds + 1);
		vec2 fu = UV * fn;
		vec2 fd = (fract(fu) - 0.5);
		vec2 ed = 0.5 - abs(fd);
		float fx = (1.0 - smoothstep(0.0, 0.04, ed.x)) * sign(fd.x) * (mod(floor(fu.x + 0.5), 2.0) * 2.0 - 1.0);
		float fy = (1.0 - smoothstep(0.0, 0.04, ed.y)) * sign(fd.y) * (mod(floor(fu.y + 0.5), 2.0) * 2.0 - 1.0);
		sh += (fx * L.x + fy * L.y) * fold_strength * 0.25;
	}
	vec3 o = s * paper.rgb * (1.0 + sh);
	COLOR = pm(o, c.a);
}
