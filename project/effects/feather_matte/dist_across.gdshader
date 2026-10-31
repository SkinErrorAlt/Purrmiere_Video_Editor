shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float reach_a = 0.0;
uniform float reach_b = 0.0;
uniform float reach_c = 0.0;
uniform float reach_d = 0.0;
uniform float reach_e = 0.0;
uniform float reach_f = 0.0;
uniform float reach_extra = 2.0;

const float DMAX = 256.0;

vec2 pack16(float v) {
	float x = clamp(v, 0.0, 1.0) * 255.0;
	float hi = floor(x);
	return vec2(hi / 255.0, x - hi);
}

void fragment() {
	float reach = (abs(reach_a) + abs(reach_b) + abs(reach_c) + abs(reach_d) + abs(reach_e) + abs(reach_f) + abs(reach_extra)) * max(px_scale, 0.0001) + 1.5;
	int n = int(min(ceil(reach), DMAX - 2.0));
	float px = 1.0 / max(tex_size.x, 1.0);
	float a0 = texture(TEXTURE, UV).a;
	float go = a0 > 0.001 ? max(0.5 - a0, 0.0) : DMAX;
	float gi = a0 < 0.999 ? max(a0 - 0.5, 0.0) : DMAX;
	for (int i = 1; i < 255; i++) {
		if (i > n) {
			break;
		}
		float fi = float(i);
		if (fi - 0.5 >= go && fi - 0.5 >= gi) {
			break;
		}
		float ar = texture(TEXTURE, clamp(UV + vec2(px * fi, 0.0), vec2(0.0), vec2(1.0))).a;
		float al = texture(TEXTURE, clamp(UV - vec2(px * fi, 0.0), vec2(0.0), vec2(1.0))).a;
		if (ar > 0.001) {
			go = min(go, fi + 0.5 - ar);
		}
		if (al > 0.001) {
			go = min(go, fi + 0.5 - al);
		}
		if (ar < 0.999) {
			gi = min(gi, fi - 0.5 + ar);
		}
		if (al < 0.999) {
			gi = min(gi, fi - 0.5 + al);
		}
	}
	COLOR = vec4(pack16(go / DMAX), pack16(gi / DMAX));
}
