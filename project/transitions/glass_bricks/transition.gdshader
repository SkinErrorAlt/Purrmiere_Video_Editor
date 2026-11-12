shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float columns : hint_range(2.0, 24.0) = 7.0;
uniform float courses : hint_range(2.0, 18.0) = 5.0;
uniform float lens : hint_range(0.0, 1.0) = 0.85;
uniform float frost : hint_range(0.0, 1.0) = 0.3;
uniform float bevel : hint_range(0.0, 1.0) = 0.85;
uniform float mortar : hint_range(0.0, 0.25) = 0.04;
uniform float tumble : hint_range(0.0, 1.0) = 0.6;
uniform float stagger : hint_range(0.0, 1.0) = 0.85;

const float GB_DONE = 0.38;

vec4 gb_face(vec2 inb, vec2 orig_uv, float nx, float ny, float sw) {
	vec2 centred = inb - 0.5;
	vec2 pull = centred * lens * 0.55;
	vec2 suv = orig_uv - vec2(pull.x / nx, pull.y / ny);
	vec2 csuv = clamp(suv, vec2(0.0), vec2(1.0));
	float lod = frost * 2.4;
	vec4 glass;
	if (sw <= 0.0) {
		glass = tr_lod(true, csuv, lod);
	} else if (sw >= 1.0) {
		glass = tr_lod(false, csuv, lod);
	} else {
		glass = mix(tr_lod(true, csuv, lod), tr_lod(false, csuv, lod), sw);
	}
	float core = smoothstep(0.5, 0.0, length(centred)) * frost * 0.35;
	glass.rgb = mix(glass.rgb, vec3(dot(glass.rgb, vec3(0.333))), core);
	float m = clamp(mortar, 0.0, 0.25);
	float lit = smoothstep(0.0, m + 0.06, inb.y) * smoothstep(0.0, m + 0.06, inb.x);
	float dark = smoothstep(0.0, m + 0.06, 1.0 - inb.y) * smoothstep(0.0, m + 0.06, 1.0 - inb.x);
	glass.rgb *= mix(1.0, mix(1.55, 1.0, lit), bevel);
	glass.rgb *= mix(1.0, mix(0.58, 1.0, dark), bevel);
	return glass;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float nx = max(columns, 2.0);
	float ny = max(courses, 2.0);
	float sw = smoothstep(GB_DONE - 0.02, GB_DONE + 0.04, p);
	vec4 col = sw <= 0.0 ? from_at(uv) : (sw >= 1.0 ? to_at(uv) : mix(from_at(uv), to_at(uv), sw));
	vec2 half_c = vec2(0.5 / nx, 0.5 / ny);
	vec2 ar = vec2(tr_ratio(), 1.0);
	float m = clamp(mortar, 0.0, 0.25);
	float ri0 = floor(uv.y * ny);
	for (int rr = 12; rr >= 0; rr--) {
		float ri = ri0 - float(rr);
		if (ri < 0.0) {
			continue;
		}
		float shiftr = mod(ri, 2.0) < 1.0 ? 0.0 : 0.5;
		float ci0 = floor(uv.x * nx + shiftr);
		for (int cc = -1; cc <= 1; cc++) {
			float ci = ci0 + float(cc);
			if (ci < 0.0 || ci > nx) {
				continue;
			}
			float bkey = fract(tr_hash(vec2(ci, ri) + 2.3) * 0.35 + (ci / nx) * 0.65);
			float bt = clamp((p - bkey * 0.18) / 0.16, 0.0, 1.0);
			if (bt <= 0.0) {
				continue;
			}
			float depth = (ri + 0.5) / ny;
			float fkey = clamp((1.0 - depth) * 0.92 + tr_hash(vec2(ci, ri) + 9.4) * 0.18, 0.0, 1.0);
			float fs = GB_DONE + 0.04 + 0.5 * fkey * clamp(stagger, 0.0, 1.0);
			float ft = clamp((p - fs) / max(1.0 - fs, 0.0001), 0.0, 1.0);
			float dropy = ft * (0.42 + 2.1 * ft);
			float rot = (tr_hash(vec2(ci, ri) + 4.8) - 0.5) * 1.4 * tumble * ft * ft;
			float grow = mix(0.62, 1.0, smoothstep(0.0, 1.0, bt));
			vec2 home = vec2((ci + 0.5 - shiftr) / nx, (ri + 0.5) / ny);
			vec2 cen = home + vec2(0.0, dropy);
			vec2 d = (uv - cen) * ar;
			float cg = cos(-rot);
			float sg = sin(-rot);
			vec2 rr2 = vec2(cg * d.x - sg * d.y, sg * d.x + cg * d.y);
			vec2 loc = rr2 / ar;
			vec2 q = loc / (half_c * grow);
			if (abs(q.x) > 1.0 || abs(q.y) > 1.0) {
				continue;
			}
			vec2 inb = q * 0.5 + 0.5;
			vec2 orig_uv = home + loc;
			vec4 face = gb_face(inb, orig_uv, nx, ny, sw);
			float edge = min(min(inb.x, 1.0 - inb.x), min(inb.y, 1.0 - inb.y));
			float inside = smoothstep(m * 0.5, m * 0.5 + 0.02, edge);
			vec4 joint = face;
			joint.rgb = joint.rgb * 0.58 + vec3(0.05);
			vec4 piece = mix(joint, face, inside);
			float fallen = smoothstep(0.0, 0.07, ft);
			float soft = 0.06;
			float rim = smoothstep(1.0, 1.0 - soft, abs(q.x)) * smoothstep(1.0, 1.0 - soft, abs(q.y));
			float alpha = bt * mix(1.0, rim * inside, fallen);
			piece.rgb *= mix(1.0, 0.75, fallen);
			col = mix(col, piece, clamp(alpha, 0.0, 1.0));
		}
	}
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
