shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)
uniform float develop : hint_range(0.3, 1.9) = 1.6;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float richness : hint_range(0.0, 1.0) = 0.75;
uniform float clean : hint_range(0.0, 1.0) = 0.8;
uniform float glow : hint_range(0.0, 1.0) = 0.5;

vec3 lin(vec3 c) {
	return c * c;
}

float dev(float frames, float fps) {
	float x = clamp(frames / max(develop * fps, 1.0), 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 runs = texelFetch(TEXTURE, ivec2(0, 0), 0) * 63.0;
	float fps = max(history_fps, 1.0);
	float u = max(max(dev(runs.x, fps), dev(runs.y, fps) * 0.55), max(dev(runs.z, fps) * 0.25, dev(runs.w, fps) * 0.08));
	u *= strength;
	if (u < 0.002) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		vec3 now = lin(src.rgb / a);
		int n = int(min(floor(runs.x), 16.0));
		vec3 acc = now;
		float wsum = 1.0;
		for (int k = 1; k <= 16; k++) {
			if (k > n) {
				break;
			}
			vec4 h = history_frame(k, UV, src);
			vec3 hl = lin(h.rgb / max(h.a, 0.0001));
			vec3 d = hl - now;
			float w = exp(-dot(d, d) / 0.004);
			acc += hl * w;
			wsum += w;
		}
		vec3 base = mix(now, acc / wsum, clean * u);
		vec2 px = uv_px * px_out;
		vec3 soft = vec3(0.0);
		vec3 bloom = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 2.39996;
			float r = 4.0 + 2.2 * float(i);
			vec3 c = lin(texture(effect_tex, UV + vec2(cos(ang), sin(ang)) * r * px).rgb / a);
			soft += c;
			bloom += max(c - 0.35, 0.0);
		}
		soft /= 12.0;
		bloom /= 12.0;
		float y = dot(base, vec3(0.2126, 0.7152, 0.0722));
		float ys = dot(soft, vec3(0.2126, 0.7152, 0.0722));
		vec3 l = base;
		l *= mix(1.0, clamp(pow(max(y, 1e-4) / max(ys, 1e-4), 0.35), 0.6, 1.6), richness * u);
		float yl = dot(l, vec3(0.2126, 0.7152, 0.0722));
		float sat = length(l - yl) / max(yl, 0.02);
		l = yl + (l - yl) * (1.0 + richness * u * (1.0 - 0.55 * clamp(sat, 0.0, 1.0)));
		l = mix(l, l * smoothstep(0.0, 0.18, yl) * 0.15 + l * 0.85, richness * u * 0.3);
		l += bloom * vec3(1.0, 0.92, 0.8) * glow * u * 0.9;
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
