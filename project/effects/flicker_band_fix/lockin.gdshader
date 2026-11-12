shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D band_tex : filter_nearest, repeat_disable;
uniform int direction = 0;

const int STRIPS = 16;
const int HARMONICS = 4;
const float BAND_SPAN = 4.0;
const float CHROMA_SPAN = 1.0;
const float TWO_PI = 6.28318530718;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float join16(float h, float l) {
	return (floor(h * 255.0 + 0.5) * 256.0 + floor(l * 255.0 + 0.5)) / 65535.0;
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

void fragment() {
	ivec2 ax = direction == 0 ? ivec2(0, 1) : ivec2(1, 0);
	ivec2 across = ivec2(1) - ax;
	int lane = int(dot(floor(FRAGCOORD.xy), vec2(across)));
	if (lane > STRIPS) {
		COLOR = vec4(0.0);
	} else {
		vec4 pk = texelFetch(TEXTURE, ivec2(0, 0), 0);
		float count = dot(vec2(textureSize(band_tex, 0)), vec2(ax));
		float per = max(join16(pk.r, pk.g) * count, 2.0);
		float gate = smoothstep(0.38, 0.55, pk.b);
		float posf = dot(UV, vec2(ax)) * count - 0.5;
		float sigma = per * 1.2;
		int reach = int(min(ceil(sigma * 2.6), count));
		int hmax = int(clamp(floor(per / 2.5), 1.0, float(HARMONICS)));
		int centre = int(floor(posf + 0.5));
		int p0 = max(centre - reach, 0);
		int p1 = min(centre + reach, int(count) - 1);
		float step_a = TWO_PI / per;
		vec3 ac[HARMONICS];
		vec3 as[HARMONICS];
		float ncc[HARMONICS];
		float nss[HARMONICS];
		for (int h = 0; h < HARMONICS; h++) {
			ac[h] = vec3(0.0);
			as[h] = vec3(0.0);
			ncc[h] = 0.0;
			nss[h] = 0.0;
		}
		float wtot = 0.0;
		float cov = 0.0;
		if (gate > 0.0) {
			for (int p = p0; p <= p1; p++) {
				float o = float(p) - posf;
				float w = exp(-0.5 * o * o / (sigma * sigma));
				wtot += w;
				vec3 b = vec3(0.0);
				if (lane < STRIPS) {
					vec4 t = texelFetch(band_tex, ax * p + across * lane, 0);
					b = vec3((join16(t.r, t.g) - 0.5) * BAND_SPAN * t.b);
					cov += t.b * w;
				} else {
					vec4 hi = texelFetch(band_tex, ax * p + across * STRIPS, 0);
					vec4 lo = texelFetch(band_tex, ax * p + across * (STRIPS + 1), 0);
					b = (vec3(join16(hi.r, lo.r), join16(hi.g, lo.g), join16(hi.b, lo.b)) - 0.5) * BAND_SPAN * hi.a;
					cov += hi.a * w;
				}
				float ph = step_a * float(p);
				vec2 e1 = vec2(cos(ph), sin(ph));
				vec2 e = e1;
				for (int h = 0; h < HARMONICS; h++) {
					if (h >= hmax) {
						break;
					}
					ac[h] += b * (e.x * w);
					as[h] += b * (e.y * w);
					ncc[h] += e.x * e.x * w;
					nss[h] += e.y * e.y * w;
					e = vec2(e.x * e1.x - e.y * e1.y, e.x * e1.y + e.y * e1.x);
				}
			}
		}
		vec3 v = vec3(0.0);
		float ph0 = step_a * posf;
		vec2 a1 = vec2(cos(ph0), sin(ph0));
		vec2 a = a1;
		for (int h = 0; h < HARMONICS; h++) {
			if (h >= hmax) {
				break;
			}
			v += ac[h] / max(ncc[h], 0.0001) * a.x + as[h] / max(nss[h], 0.0001) * a.y;
			a = vec2(a.x * a1.x - a.y * a1.y, a.x * a1.y + a.y * a1.x);
		}
		v *= gate;
		bool ok = gate > 0.0 && cov >= wtot * 0.5;
		if (lane < STRIPS) {
			vec2 q = split16(v.x / BAND_SPAN + 0.5);
			COLOR = vec4(q.x, q.y, ok ? 1.0 : 0.0, 1.0);
		} else {
			float lum = dot(v, LUMA);
			vec3 chroma = v - vec3(lum);
			vec2 q = split16(lum / BAND_SPAN + 0.5);
			vec2 cr = clamp(chroma.rb / CHROMA_SPAN + 0.5, 0.0, 1.0);
			COLOR = vec4(q.x, q.y, cr.x, cr.y);
		}
	}
}
