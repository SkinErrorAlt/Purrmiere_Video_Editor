shader_type canvas_item;
render_mode blend_disabled;

uniform int page : hint_range(0, 2) = 0;
uniform float border : hint_range(0.0, 80.0) = 16.0;
uniform float corner : hint_range(10.0, 200.0) = 46.0;
uniform vec4 corner_colour : source_color = vec4(0.08, 0.07, 0.07, 1.0);
uniform float margin : hint_range(0.0, 0.3) = 0.1;
uniform float tilt : hint_range(-15.0, 15.0) = -2.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

float rbox(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P0 = UV * S - S * 0.5;
	vec2 P = rot(radians(-tilt)) * P0;
	vec2 hb = S * 0.5 - margin * S.y;
	float dph = rbox(P, hb);
	vec2 ib = hb - border;
	vec2 suv = P / max(ib, vec2(1.0)) * 0.5 + 0.5;
	vec4 c = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	float pic = smoothstep(0.8, -0.8, rbox(P, ib));
	float photo = smoothstep(0.8, -0.8, dph);
	vec4 bg = vec4(0.12, 0.1, 0.09, 1.0);
	if (page == 1) {
		bg = vec4(0.93, 0.89, 0.8, 1.0);
	} else if (page == 2) {
		bg = vec4(0.0);
	}
	bg.rgb *= 0.92 + 0.08 * vn(P0 * 0.3);
	float sd = rbox(P - vec2(5.0, 8.0), hb);
	float sha = (1.0 - smoothstep(-4.0, 18.0, sd)) * shadow * 0.6;
	vec4 o = bg * (1.0 - sha * 0.6) + vec4(0.0, 0.0, 0.0, sha) * (1.0 - bg.a);
	vec4 ph = mix(vec4(0.97, 0.96, 0.93, 1.0), over(c, vec4(0.97, 0.96, 0.93, 1.0)), pic);
	o = mix(o, ph, photo);
	vec2 a = abs(P) - hb;
	vec2 cq = vec2(-a.x, -a.y);
	float tri = step(0.0, cq.x + border * 0.3) * step(0.0, cq.y + border * 0.3) * step(cq.x + cq.y, corner);
	o = mix(o, vec4(corner_colour.rgb * (0.9 + 0.2 * smoothstep(corner, 0.0, cq.x + cq.y)), 1.0), tri);
	COLOR = o;
}
