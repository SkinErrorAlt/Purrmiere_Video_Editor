shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 title_a : source_color = vec4(0.05, 0.1, 0.5, 1.0);
uniform vec4 title_b : source_color = vec4(0.35, 0.55, 0.85, 1.0);
uniform vec4 frame : source_color = vec4(0.76, 0.76, 0.76, 1.0);
uniform float margin : hint_range(0.0, 0.3) = 0.06;
uniform float bar : hint_range(10.0, 80.0) = 30.0;
uniform float border : hint_range(2.0, 30.0) = 6.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 over(vec4 t, vec4 b) { return t + b * (1.0 - t.a); }

float bevel(vec2 P, vec2 lo, vec2 hi, float w) {
	vec2 a = P - lo;
	vec2 b = hi - P;
	float tl = step(min(a.x, a.y), w) * step(min(a.x, a.y), min(b.x, b.y));
	float br = step(min(b.x, b.y), w) * step(min(b.x, b.y), min(a.x, a.y));
	return tl - br;
}

void fragment() {
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P = UV * S;
	float m = margin * S.y;
	vec2 lo = vec2(m);
	vec2 hi = S - m;
	float inwin = step(lo.x, P.x) * step(P.x, hi.x) * step(lo.y, P.y) * step(P.y, hi.y);
	vec2 so = P - vec2(8.0, 10.0);
	float sh = step(lo.x, so.x) * step(so.x, hi.x) * step(lo.y, so.y) * step(so.y, hi.y) * (1.0 - inwin) * shadow * 0.5;
	vec2 blo = lo + border;
	vec2 bhi = vec2(hi.x - border, lo.y + border + bar);
	float inbar = step(blo.x, P.x) * step(P.x, bhi.x) * step(blo.y, P.y) * step(P.y, bhi.y);
	vec2 clo = vec2(lo.x + border, bhi.y + 2.0);
	vec2 chi = hi - border;
	float incl = step(clo.x, P.x) * step(P.x, chi.x) * step(clo.y, P.y) * step(P.y, chi.y);
	vec2 cuv = (P - clo) / max(chi - clo, vec2(1.0));
	vec4 c = texture(TEXTURE, cuv);
	vec3 o = frame.rgb;
	float bv = bevel(P, lo, hi, 2.0);
	o = mix(o, vec3(1.0), max(bv, 0.0) * 0.9);
	o = mix(o, vec3(0.3), max(-bv, 0.0) * 0.9);
	vec3 tb = mix(title_a.rgb, title_b.rgb, (P.x - blo.x) / max(bhi.x - blo.x, 1.0));
	o = mix(o, tb, inbar);
	for (int i = 0; i < 3; i++) {
		float bs = bar - 8.0;
		vec2 bc = vec2(bhi.x - 4.0 - bs * 0.5 - float(i) * (bs + 3.0), (blo.y + bhi.y) * 0.5);
		vec2 d = abs(P - bc);
		float btn = step(max(d.x, d.y), bs * 0.5);
		float bb = bevel(P, bc - bs * 0.5, bc + bs * 0.5, 1.5);
		vec3 bcol = mix(frame.rgb, vec3(1.0), max(bb, 0.0));
		bcol = mix(bcol, vec3(0.3), max(-bb, 0.0));
		float sym = 0.0;
		vec2 q = P - bc;
		if (i == 0) {
			sym = step(min(abs(q.x - q.y), abs(q.x + q.y)), 1.4) * step(max(abs(q.x), abs(q.y)), bs * 0.28);
		} else if (i == 1) {
			sym = step(max(abs(q.x), abs(q.y)), bs * 0.3) * (1.0 - step(max(abs(q.x), abs(q.y - 1.5)), bs * 0.3 - 1.5));
		} else {
			sym = step(abs(q.y - bs * 0.22), 1.2) * step(abs(q.x), bs * 0.28);
		}
		bcol = mix(bcol, vec3(0.05), sym);
		o = mix(o, bcol, btn);
	}
	vec4 res = vec4(o, 1.0) * inwin;
	res = mix(res, over(c, vec4(0.0, 0.0, 0.0, 1.0)), incl);
	res = res + vec4(0.0, 0.0, 0.0, sh) * (1.0 - res.a);
	COLOR = res;
}
