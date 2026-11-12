shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform sampler2D near_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float seq_fps = 30.0;
uniform float ahead = 0.4;
uniform int ghosts = 3;
uniform float opacity = 0.85;
uniform float ignore_under = 0.8;
uniform bool camera = true;
uniform vec4 tint : source_color = vec4(0.62, 0.85, 1.0, 1.0);
uniform float glow = 0.4;

vec2 scene_motion(vec2 uv) {
	return motion_at(flow_tex, uv) - (camera ? kit_global(global_tex, uv) : vec2(0.0));
}

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 pic = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec3 outc = pic;
	float frames = ahead * max(seq_fps, 1.0);
	int n = clamp(ghosts, 1, 6);
	vec2 q = UV * out_size;
	for (int g = 6; g >= 1; g--) {
		if (g > n) {
			continue;
		}
		float T = frames * float(g) / float(n);
		vec2 V = -flow_decode(texelFetch(near_tex, ivec2(floor(UV * vec2(textureSize(near_tex, 0)))), 0));
		vec2 x = q - V * T;
		for (int it = 0; it < 4; it++) {
			x = q - scene_motion(x / out_size) * T;
		}
		vec2 xu = x / out_size;
		if (xu.x < 0.0 || xu.y < 0.0 || xu.x > 1.0 || xu.y > 1.0) {
			continue;
		}
		vec2 v = scene_motion(xu);
		float sp = length(v) / ps;
		float mover = smoothstep(ignore_under, ignore_under * 2.0 + 1.0, sp);
		float miss = length(x + v * T - q) / max(ps, 0.1);
		mover *= 1.0 - smoothstep(3.0, 10.0, miss);
		vec4 gc = texture(effect_tex, xu);
		vec3 gcol = gc.a > 0.0001 ? gc.rgb / gc.a : vec3(0.0);
		float differs = smoothstep(0.025, 0.10, length(gcol - pic));
		float fade = 1.0 - 0.55 * (float(g) - 1.0) / max(float(n), 1.0);
		float w = mover * differs * opacity * fade;
		vec3 ghost = mix(gcol, gcol * tint.rgb + tint.rgb * 0.12, 0.6);
		vec3 lit = outc + ghost * glow * 0.5;
		outc = mix(outc, mix(ghost, lit, glow * 0.5), w);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
