shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float snow : hint_range(0.0, 1.0) = 0.6;
uniform float grow_time : hint_range(0.0, 30.0) = 0.0;
uniform float dusting : hint_range(0.0, 1.0) = 0.25;
uniform float chill : hint_range(0.0, 1.0) = 0.5;
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 289.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec2 osz = vec2(textureSize(effect_tex, 0));
	vec2 opx = 1.0 / max(osz, vec2(1.0));
	float ps = max(px_scale * 4.0, 0.0001);
	float amt = clamp(snow, 0.0, 1.0);
	if (grow_time > 0.0001) {
		amt *= clamp(max(clip_time, 0.0) / grow_time, 0.0, 1.0);
	}
	float sk = mod(float(seed), 997.0);
	vec2 pix = UV * osz;
	vec4 base = texture(effect_tex, UV);
	float a = base.a;
	vec3 rgb = unpm(base);
	vec4 cap = texture(TEXTURE, UV);
	float grain = vnoise(pix / max(2.5 * ps, 1.0) + sk) * 0.5 + vnoise(pix / max(9.0 * ps, 1.0) + sk * 1.3) * 0.5;
	float thr = mix(0.5, 0.22, amt);
	float m = smoothstep(thr, thr + 0.06, cap.r + (grain - 0.5) * 0.14);
	m *= smoothstep(0.0, 0.08, amt);
	float l0 = dot(rgb, LUMA);
	float lu = dot(unpm(texture(effect_tex, UV - vec2(0.0, 1.5) * opx * ps)), LUMA);
	float ld = dot(unpm(texture(effect_tex, UV + vec2(0.0, 1.5) * opx * ps)), LUMA);
	float ll = dot(unpm(texture(effect_tex, UV - vec2(1.5, 0.0) * opx * ps)), LUMA);
	float lr = dot(unpm(texture(effect_tex, UV + vec2(1.5, 0.0) * opx * ps)), LUMA);
	float fine = clamp((abs(ld - lu) - 0.9 * abs(lr - ll) - 0.05) * 5.0, 0.0, 1.0);
	float fleck = smoothstep(0.55, 0.8, vnoise(pix / max(1.8 * ps, 1.0) + sk * 2.1));
	float dust = fine * fleck * dusting * amt * 1.4;
	vec3 cold = mix(rgb, vec3(l0), 0.35 * chill);
	cold *= mix(vec3(1.0), vec3(0.9, 0.97, 1.08), chill);
	cold = mix(cold, cold * 0.88 + vec3(0.07, 0.08, 0.1), chill * 0.6);
	float top = clamp(-dFdy(m) * 6.0, 0.0, 1.0);
	vec3 white = vec3(0.95, 0.97, 1.0);
	vec3 shade = vec3(0.68, 0.76, 0.88);
	vec3 sn = mix(shade, white, smoothstep(0.0, 0.7, cap.g) * 0.6 + 0.4);
	sn *= 0.82 + 0.3 * smoothstep(0.0, 0.8, l0);
	sn = mix(sn, vec3(1.0), top * 0.6);
	sn *= 0.94 + 0.08 * grain;
	vec3 col = mix(cold, sn, m);
	col = mix(col, white * (0.85 + 0.15 * l0), clamp(dust, 0.0, 1.0) * (1.0 - m));
	vec2 gc = floor(pix / max(3.0 * ps, 1.0));
	float gl = step(0.993, hash12(mod(gc, 4096.0) + sk)) * max(m, dust) * sparkle;
	col += vec3(0.6) * gl;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
