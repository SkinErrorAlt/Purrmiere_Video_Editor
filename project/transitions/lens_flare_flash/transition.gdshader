shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int path = 0;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float size : hint_range(0.3, 3.0) = 1.0;
uniform float streak : hint_range(0.0, 1.0) = 0.6;
uniform bool ghosts = true;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.9;

vec2 flare_pos(float p) {
	float hw = tr_ratio() * 0.5;
	vec2 a = vec2(-hw * 1.05, 0.3);
	vec2 b = vec2(hw * 1.05, -0.1);
	if (path == 1) {
		a = vec2(hw * 1.05, 0.3);
		b = vec2(-hw * 1.05, -0.1);
	} else if (path == 2) {
		a = vec2(hw * 0.25, 0.62);
		b = vec2(-hw * 0.15, -0.62);
	} else if (path == 3) {
		a = vec2(-hw * 0.25, -0.62);
		b = vec2(hw * 0.15, 0.62);
	} else if (path == 4) {
		a = vec2(hw * 0.12, 0.1);
		b = vec2(hw * 0.12, 0.1);
	}
	return mix(a, b, tr_ease(p, 3));
}

vec3 ghost(vec2 q, vec2 c, float r, vec3 col) {
	float d = length(q - c);
	float disc = 1.0 - smoothstep(r * 0.75, r, d);
	float rim = exp(-pow((d - r * 0.9) / (r * 0.12), 2.0));
	return col * (disc * 0.12 + rim * 0.1);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 base = mix(from_at(uv), to_at(uv), smoothstep(0.4, 0.6, p));
	float s = sin(TR_PI * clamp(p, 0.0, 1.0));
	if (s <= 0.0) {
		return base;
	}
	float env = pow(s, 1.5);
	float flash = pow(s, 10.0) * flash_amount;
	vec2 q = tr_world(uv);
	vec2 pos = flare_pos(p);
	vec2 d = q - pos;
	float r = length(d);
	float sz = size * (path == 4 ? 0.4 + 0.8 * s : 1.0);
	vec3 tc = tint.rgb;
	float core = exp(-r * r / (0.0035 * sz * sz)) * 1.5;
	float glow = exp(-r / (0.11 * sz)) * 0.7 + exp(-r / (0.45 * sz)) * 0.18;
	float ang = atan(d.y, d.x);
	float rays = (pow(abs(cos(ang * 3.0 + 0.4)), 60.0) + 0.6 * pow(abs(cos(ang * 4.0 + 1.3)), 90.0)) * exp(-r / (0.16 * sz)) * 0.6;
	float st = exp(-abs(d.y) / (0.005 * sz)) * exp(-abs(d.x) / (0.7 * sz)) * streak * 1.2;
	vec3 ring = vec3(
		exp(-pow((r - 0.30 * sz) / (0.01 * sz), 2.0)),
		exp(-pow((r - 0.31 * sz) / (0.01 * sz), 2.0)),
		exp(-pow((r - 0.32 * sz) / (0.01 * sz), 2.0))) * 0.08;
	vec3 light = vec3(core) + tc * (glow + rays) + vec3(0.55, 0.75, 1.0) * st + ring;
	if (ghosts) {
		light += ghost(q, pos * (1.0 - 2.0 * 0.62), 0.035 * sz, vec3(0.5, 1.0, 0.6));
		light += ghost(q, pos * (1.0 - 2.0 * 0.82), 0.075 * sz, vec3(0.7, 0.5, 1.0));
		light += ghost(q, pos * (1.0 - 2.0 * 1.1), 0.025 * sz, vec3(1.0, 0.6, 0.3));
		light += ghost(q, pos * (1.0 - 2.0 * 1.35), 0.11 * sz, vec3(0.4, 0.7, 1.0));
	}
	light = light * env * intensity + mix(vec3(1.0), tc, 0.3) * flash;
	float a = max(base.a, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
	vec3 rgb = base.rgb + light * (1.0 - base.rgb * 0.5);
	return vec4(clamp(rgb, vec3(0.0), vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
