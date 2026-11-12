shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float time = 0.0;
uniform int look : hint_range(0, 2) = 0;
uniform float burn_length : hint_range(0.2, 2.0) = 0.8;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 burn_colour : source_color = vec4(1.0, 0.36, 0.06, 1.0);
uniform vec4 hot_colour : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform float ragged : hint_range(0.0, 1.0) = 0.65;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 5; i++) {
		s += w * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		w *= 0.5;
	}
	return s / 0.97;
}

vec4 block(sampler2D t, int k) {
	ivec2 sz = textureSize(t, 0);
	return texelFetch(t, ivec2(clamp(int((float(k) + 0.5) / 4.0 * float(sz.x)), 0, sz.x - 1), 0), 0);
}

vec3 lin(vec3 c) {
	return c * c;
}

vec3 screen(vec3 a, vec3 b) {
	return 1.0 - (1.0 - a) * (1.0 - b);
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec4 b0 = block(TEXTURE, 0);
	float s = b0.r * 63.0;
	float fps = max(history_fps, 1.0);
	float span = min(burn_length * fps, 58.0);
	if (b0.r > 0.995 || s > span || strength <= 0.0) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		vec3 rgb = src.rgb / a;
		float u = s / span;
		float hard = b0.g;
		vec2 o = b0.ba;
		float cut_frame = floor(time * fps + 0.0001) - floor(s + 0.5);
		float seed = hash12(vec2(cut_frame * 0.137, 3.1)) * 91.0;
		float asp = tex_size.x / max(tex_size.y, 1.0);
		vec2 p = vec2((UV.x - o.x) * asp, UV.y - o.y);
		float tt = s / fps;
		vec3 outc = rgb;
		float g = strength * mix(0.55, 1.0, hard);
		if (look == 0) {
			float reach = length(vec2(max(o.x, 1.0 - o.x) * asp, max(o.y, 1.0 - o.y))) + 0.35;
			float r = reach * pow(1.0 - u, 2.6) * mix(0.6, 1.0, g);
			float n1 = fbm(p * 2.4 + vec2(seed, seed * 0.7) + vec2(tt * 0.6, -tt * 0.9));
			float n2 = fbm(p * 7.5 + vec2(-seed, tt * 2.2));
			float rg = clamp(ragged, 0.0, 1.0);
			float d = length(p) + ((n1 - 0.5) * 0.9 + (n2 - 0.5) * 0.28) * rg * (0.4 + 0.6 * clamp(r * 1.5, 0.0, 1.0));
			float inside = d - r;
			float edge = 0.05 + 0.07 * rg;
			float core = 1.0 - smoothstep(-edge * 2.2, -edge * 0.3, inside);
			float rim = exp(-pow(inside / edge, 2.0));
			float scorch = smoothstep(edge * 2.5, 0.0, inside) * (1.0 - core);
			float char_line = exp(-pow((inside - edge * 1.1) / (edge * 0.35), 2.0)) * smoothstep(0.35, 0.65, n2);
			float flick = 0.85 + 0.15 * vnoise(vec2(tt * 24.0, seed));
			vec3 hot = lin(hot_colour.rgb);
			vec3 burn = lin(burn_colour.rgb);
			vec3 l = lin(rgb);
			float spill = (1.0 - u) * (1.0 - u) * 0.9 * g;
			l = l * (1.0 + spill * burn * 2.2) + spill * 0.12 * burn;
			l = mix(l, l * burn * 1.6 + burn * 0.25, scorch * 0.75 * g);
			l *= 1.0 - char_line * 0.7 * g * (1.0 - core);
			l += rim * g * flick * (burn * 2.4 + hot * 0.6);
			float blister = fbm(p * 18.0 + vec2(seed * 1.3, tt * 3.0));
			vec3 blown = lin(rgb) * 9.0 * hot + hot * 1.4;
			vec3 white = mix(blown, vec3(3.0), smoothstep(0.35, 0.75, blister) * smoothstep(-edge * 4.0, -edge * 1.5, -inside - edge * 2.0));
			white = mix(white, burn * 1.5, smoothstep(0.62, 0.8, blister) * 0.5);
			l = mix(l, white, core * g * flick);
			outc = sqrt(clamp(l / (1.0 + l * 0.08), 0.0, 1.0));
		} else if (look == 1) {
			float side = o.x < 0.5 ? UV.x : 1.0 - UV.x;
			float n = fbm(vec2(UV.y * 1.8 + seed, tt * 0.7));
			float env = exp(-u * 3.0) * (1.0 - exp(-tt * 40.0 - 0.6));
			float wash = exp(-side / (0.25 + 0.55 * (1.0 - u) + 0.2 * n)) * env * g;
			vec3 c1 = lin(burn_colour.rgb);
			vec3 c2 = lin(hot_colour.rgb);
			vec3 leak = mix(c1, c2, smoothstep(0.0, 0.6, side + n * 0.3)) * 1.6;
			float glow = env * g * 0.35 * exp(-length(p) * 1.2);
			vec3 l = lin(rgb);
			l = l + leak * (wash * 1.4 + glow) + l * leak * wash * 0.8;
			outc = sqrt(clamp(l / (1.0 + l * 0.12), 0.0, 1.0));
		} else {
			float env = exp(-s / max(span * 0.18, 0.8));
			float ex = exp2(env * 3.2 * g);
			vec2 slip = vec2(0.0, (hash12(vec2(s, seed)) - 0.5) * 0.02 * env);
			vec3 l = lin(texture(effect_tex, UV + slip).rgb / a) * ex;
			l = mix(l, l * lin(hot_colour.rgb) * 1.8, env * 0.6 * g);
			l += env * env * g * 0.25 * lin(hot_colour.rgb);
			outc = sqrt(clamp(l / (1.0 + l * 0.15), 0.0, 1.0));
		}
		COLOR = vec4(outc * a, a);
	}
}
