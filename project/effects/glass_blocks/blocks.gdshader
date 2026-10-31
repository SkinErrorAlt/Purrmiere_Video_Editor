shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float size : hint_range(8.0, 600.0) = 80.0;
uniform float refraction : hint_range(-1.0, 1.0) = 0.35;
uniform float bevel : hint_range(0.0, 0.5) = 0.15;
uniform int shape : hint_range(0, 2) = 0;
uniform float shine : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec2 res = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float s = max(size * ps, 4.0);
	vec2 pix = UV * res;
	vec2 centre;
	vec2 q;
	float hs = 0.5 * s;
	float d;
	vec2 nrm;
	if (shape == 2) {
		vec2 p = pix / s;
		vec4 sv = vec4(1.0, 1.7320508, 1.0, 1.7320508);
		vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / sv) + 0.5;
		vec2 ha = p - hc.xy * sv.xy;
		vec2 hb = p - (hc.zw + 0.5) * sv.xy;
		vec2 local;
		vec2 cid;
		if (dot(ha, ha) < dot(hb, hb)) {
			local = ha;
			cid = hc.xy * sv.xy;
		} else {
			local = hb;
			cid = (hc.zw + 0.5) * sv.xy;
		}
		centre = cid * s;
		q = local * s;
		vec2 aq = abs(local);
		float d1 = aq.x;
		float d2 = dot(aq, vec2(0.5, 0.8660254));
		d = (max(d1, d2) - 0.5) * s;
		nrm = d1 > d2 ? vec2(sign(local.x), 0.0) : vec2(0.5 * sign(local.x), 0.8660254 * sign(local.y));
	} else {
		vec2 cell = floor(pix / s);
		centre = (cell + 0.5) * s;
		q = pix - centre;
		if (shape == 1) {
			float r = length(q);
			d = r - hs;
			nrm = r > 0.0001 ? q / r : vec2(0.0);
		} else {
			vec2 aq = abs(q);
			d = max(aq.x, aq.y) - hs;
			nrm = aq.x > aq.y ? vec2(sign(q.x), 0.0) : vec2(0.0, sign(q.y));
		}
	}
	if (d > 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float depth = -d;
		float bw = clamp(bevel, 0.0, 0.5) * 2.0 * hs;
		float bt = bw > 0.0001 ? 1.0 - clamp(depth / bw, 0.0, 1.0) : 0.0;
		bt = bt * bt;
		vec2 lens = q * (1.0 - refraction);
		vec2 bend = -nrm * bt * hs * 0.3;
		vec2 src = (centre + lens + bend) / res;
		vec4 c = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		float facing = dot(nrm, vec2(-0.70710678, -0.70710678));
		float hi = max(facing, 0.0) * bt;
		float lo = max(-facing, 0.0) * bt;
		float seam = 1.0 - smoothstep(0.0, max(1.5 * ps, 1.0), depth);
		float sh = clamp(shine, 0.0, 1.0);
		rgb *= 1.0 - sh * lo * 0.45;
		rgb += vec3(sh * hi * 0.6);
		rgb *= 1.0 - sh * seam * 0.35;
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
