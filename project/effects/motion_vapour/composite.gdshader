shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform int kind = 0;
uniform float strength = 1.1;
uniform vec4 smoke_colour : source_color = vec4(0.82, 0.82, 0.84, 1.0);

vec4 vap(sampler2D t, vec2 uv, vec2 px) {
	vec4 acc = vec4(0.0);
	float ws = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			float w = (i == 0 && j == 0) ? 4.0 : ((i == 0 || j == 0) ? 2.0 : 1.0);
			vec4 c = texture(t, uv + vec2(float(i), float(j)) * px);
			acc += vec4(c.rgb * c.a, c.a) * w;
			ws += w;
		}
	}
	acc /= ws;
	return vec4(acc.a > 1e-4 ? acc.rgb / acc.a : vec3(0.0), acc.a);
}

vec3 flame(float t) {
	vec3 c = mix(vec3(0.0), vec3(0.75, 0.10, 0.02), smoothstep(0.0, 0.3, t));
	c = mix(c, vec3(1.0, 0.45, 0.06), smoothstep(0.25, 0.6, t));
	c = mix(c, vec3(1.0, 0.85, 0.45), smoothstep(0.55, 0.85, t));
	return mix(c, vec3(1.0, 0.98, 0.9), smoothstep(0.85, 1.0, t));
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	vec2 vsz = vec2(textureSize(TEXTURE, 0));
	vec2 vpx = 1.0 / vsz;
	vec4 v = vap(TEXTURE, UV, vpx);
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 pic = a > 0.0001 ? src.rgb / a : vec3(0.0);
	float D = v.a * strength;
	vec3 outc = pic;
	if (kind == 0) {
		vec3 vc = mix(v.rgb, vec3(1.0), 0.2) * 1.5;
		outc = 1.0 - (1.0 - pic) * (1.0 - clamp(vc * D, 0.0, 1.0));
	} else if (kind == 1) {
		float up = vap(TEXTURE, UV - vec2(0.0, 2.0) * vpx, vpx).a;
		float dn = vap(TEXTURE, UV + vec2(0.0, 2.0) * vpx, vpx).a;
		float light = clamp(0.85 + (dn - up) * 2.5, 0.55, 1.2);
		vec3 sc = smoke_colour.rgb * light;
		outc = mix(pic, sc, clamp(D * 0.9, 0.0, 0.92));
	} else if (kind == 2) {
		float t = clamp(D * 1.15, 0.0, 1.0);
		vec3 f = flame(t);
		vec3 base = pic * (1.0 - 0.25 * smoothstep(0.0, 0.4, D));
		outc = 1.0 - (1.0 - base) * (1.0 - clamp(f * smoothstep(0.02, 0.5, D) * 1.1, 0.0, 1.0));
	} else {
		float l = vap(TEXTURE, UV - vec2(1.5, 0.0) * vpx, vpx).a;
		float r = vap(TEXTURE, UV + vec2(1.5, 0.0) * vpx, vpx).a;
		float u = vap(TEXTURE, UV - vec2(0.0, 1.5) * vpx, vpx).a;
		float d = vap(TEXTURE, UV + vec2(0.0, 1.5) * vpx, vpx).a;
		vec2 g = vec2(r - l, d - u);
		vec2 off = g * strength * 40.0 / out_size * max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
		vec4 bent = texture(effect_tex, clamp(UV + off, vec2(0.0), vec2(1.0)));
		outc = bent.a > 0.0001 ? bent.rgb / bent.a : pic;
		outc *= 1.0 + D * 0.04;
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
