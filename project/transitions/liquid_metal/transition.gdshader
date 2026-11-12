shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float flow : hint_range(0.0, 0.45) = 0.17;
uniform float swirl : hint_range(0.0, 1.0) = 0.72;
uniform float molten : hint_range(0.0, 1.0) = 0.55;
uniform float highlight : hint_range(0.0, 2.0) = 0.8;
uniform float grain : hint_range(1.0, 12.0) = 2.6;
uniform vec4 tint : source_color = vec4(0.86, 0.89, 0.95, 1.0);

float lm_pot(vec2 uv, float t) {
	return tr_fbm(uv * grain + vec2(t * 0.62, -t * 0.47));
}

vec2 lm_field(vec2 uv, float t) {
	float e = 0.5 / max(grain, 1.0);
	float dx = lm_pot(uv + vec2(e, 0.0), t) - lm_pot(uv - vec2(e, 0.0), t);
	float dy = lm_pot(uv + vec2(0.0, e), t) - lm_pot(uv - vec2(0.0, e), t);
	vec2 g = vec2(dx, dy) * 1.6;
	vec2 c = vec2(dy, -dx) * 1.6;
	return mix(g, c, clamp(swirl, 0.0, 1.0));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float melt = sin(p * TR_PI);
	float t = p * 2.4;
	float amt = flow * melt / 3.0;
	vec2 cur = uv;
	for (int i = 0; i < 3; i++) {
		cur += lm_field(cur, t) * amt;
	}
	cur = clamp(cur, vec2(-0.2), vec2(1.2));
	float h = lm_pot(cur, t + 0.4);
	float e2 = 0.8 / max(grain, 1.0);
	float sx = lm_pot(cur + vec2(e2, 0.0), t + 0.4) - h;
	float sy = lm_pot(cur + vec2(0.0, e2), t + 0.4) - h;
	vec2 slope = vec2(sx, sy) * 2.2;
	float sw = clamp((p - 0.26) / 0.46, 0.0, 1.0);
	float bias = (h - 0.5) * 0.6 * molten;
	float k = smoothstep(0.0, 1.0, clamp(sw * 2.0 - 0.5 + bias, 0.0, 1.0));
	vec2 suv = clamp(cur, vec2(0.0), vec2(1.0));
	vec4 base = mix(from_clamped(suv), to_clamped(suv), k);
	vec3 nrm = normalize(vec3(-slope, 1.0));
	vec3 lgt = normalize(vec3(0.42, -0.66, 0.62));
	float lam = clamp(dot(nrm, lgt), 0.0, 1.0);
	float spec = pow(lam, 11.0);
	float fres = pow(1.0 - clamp(nrm.z, 0.0, 1.0), 2.4);
	vec3 metal = mix(base.rgb, base.rgb * 0.62 + tint.rgb * 0.42, molten * melt * 0.5);
	metal *= mix(1.0, 0.76 + 0.52 * lam, molten * melt * 0.8);
	metal += tint.rgb * spec * highlight * melt * 0.9;
	metal += tint.rgb * fres * molten * melt * 0.18;
	vec3 outc = mix(base.rgb, metal, melt);
	return vec4(outc, base.a);
}

void fragment() {
	COLOR = transition(UV);
}
