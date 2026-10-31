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

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

void fragment() {
	float reach = (abs(reach_a) + abs(reach_b) + abs(reach_c) + abs(reach_d) + abs(reach_e) + abs(reach_f) + abs(reach_extra)) * max(px_scale, 0.0001) + 1.5;
	int n = int(min(ceil(reach), DMAX - 2.0));
	float py = 1.0 / max(tex_size.y, 1.0);
	vec4 c = texture(TEXTURE, UV);
	float bo = unpack16(c.rg);
	float bi = unpack16(c.ba);
	for (int j = 1; j < 255; j++) {
		if (j > n) {
			break;
		}
		float fj = float(j);
		if (fj >= bo && fj >= bi) {
			break;
		}
		vec4 u = texture(TEXTURE, clamp(UV + vec2(0.0, py * fj), vec2(0.0), vec2(1.0)));
		vec4 d = texture(TEXTURE, clamp(UV - vec2(0.0, py * fj), vec2(0.0), vec2(1.0)));
		float ho = min(unpack16(u.rg), unpack16(d.rg));
		float hi = min(unpack16(u.ba), unpack16(d.ba));
		if (ho < DMAX - 0.5) {
			bo = min(bo, sqrt(ho * ho + fj * fj));
		}
		if (hi < DMAX - 0.5) {
			bi = min(bi, sqrt(hi * hi + fj * fj));
		}
	}
	COLOR = vec4(pack16(bo / DMAX), pack16(bi / DMAX));
}
